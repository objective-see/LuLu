#!/usr/bin/env python3
"""Prepare and observe local canaries; never install a provider or change rules."""
import argparse
import hashlib
import json
import pathlib
import shutil
import socket
import subprocess
import threading


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def reserve(family, kind, address):
    with socket.socket(family, kind) as connection:
        connection.bind((address, 0))
        return connection.getsockname()[1]


def prepare(folder):
    if folder.exists() and any(folder.iterdir()):
        raise RuntimeError("Prepare requires a new or empty directory")
    folder.mkdir(parents=True, exist_ok=True)
    root = folder / "selected-root" / "canary"
    child = folder / "external-child" / "canary"
    root.parent.mkdir()
    child.parent.mkdir()
    subprocess.run(["xcrun", "clang", "-Wall", "-Wextra", "-O2",
                    str(pathlib.Path(__file__).with_name("canary.c")), "-o", str(root)], check=True)
    shutil.copy2(root, child)
    subprocess.run(["codesign", "--verify", "--strict", str(root)], check=True, capture_output=True)
    metadata = subprocess.run(["codesign", "-d", "--verbose=4", str(root)],
                              check=True, capture_output=True, text=True).stderr
    fields = dict(line.split("=", 1) for line in metadata.splitlines() if "=" in line)
    cdhash = fields.get("CDHash", "")
    if len(cdhash) != 40 or any(character not in "0123456789abcdefABCDEF" for character in cdhash):
        raise RuntimeError("A verified 20-byte native code hash is required")
    if fields.get("Signature") != "adhoc":
        raise RuntimeError("This prepared fixture expects the compiler's local ad-hoc signature")
    signing = {"signatureStatus": 0, "signatureSigner": 4,
               "signatureIdentifier": fields["Identifier"], "signatureCDHash": cdhash.lower()}
    cases = [{"name": "allowed_tcp", "host": "127.0.0.1", "protocol": "tcp"},
             {"name": "other_tcp", "host": "127.0.0.1", "protocol": "tcp"},
             {"name": "ipv6_tcp", "host": "::1", "protocol": "tcp"},
             {"name": "ipv4_udp", "host": "127.0.0.1", "protocol": "udp"},
             {"name": "ipv6_udp", "host": "::1", "protocol": "udp"}]
    reserved = set()
    for case in cases:
        while True:
            port = reserve(socket.AF_INET6 if ":" in case["host"] else socket.AF_INET,
                           socket.SOCK_STREAM if case["protocol"] == "tcp" else socket.SOCK_DGRAM,
                           case["host"])
            endpoint = (case["host"], port, case["protocol"])
            if endpoint not in reserved:
                reserved.add(endpoint)
                case["port"] = port
                break
    config = {"root": str(root), "child": str(child), "cases": cases}
    write_json(folder / "config.json", config)
    write_json(folder / "rule-info.json", [
        {"path": str(root), "type": 3, "scope": 3, "action": 1, "protocol": 6,
         "endpointAddr": "127.0.0.1", "endpointPort": str(cases[0]["port"]), "signingInfo": signing},
        {"path": str(child), "type": 3, "scope": 0, "action": 1}])
    print(f"Prepared {folder}\nSelected exact root: {root}")
    print(f"Allow only TCP 127.0.0.1:{cases[0]['port']}; child own-Allow fixture: rule-info.json")
    print("Run baseline first. Configure a legally signed provider separately before strict mode.")


def server(case, stop):
    family = socket.AF_INET6 if ":" in case["host"] else socket.AF_INET
    kind = socket.SOCK_STREAM if case["protocol"] == "tcp" else socket.SOCK_DGRAM
    connection = socket.socket(family, kind)
    connection.bind((case["host"], case["port"]))
    if kind == socket.SOCK_STREAM:
        connection.listen(16)
    connection.settimeout(0.2)

    def echo():
        while not stop.is_set():
            try:
                if kind == socket.SOCK_DGRAM:
                    data, peer = connection.recvfrom(256)
                    connection.sendto(data, peer)
                else:
                    peer, _ = connection.accept()
                    with peer:
                        peer.settimeout(1)
                        data = peer.recv(256)
                        if data:
                            peer.sendall(data)
            except (TimeoutError, socket.timeout):
                continue
        connection.close()
    worker = threading.Thread(target=echo, daemon=True)
    worker.start()
    return worker


def run(folder, mode):
    config = json.loads((folder / "config.json").read_text())
    fingerprint = hashlib.sha256((folder / "config.json").read_bytes() +
                                 pathlib.Path(config["root"]).read_bytes() +
                                 pathlib.Path(config["child"]).read_bytes() +
                                 (folder / "rule-info.json").read_bytes()).hexdigest()
    if mode == "strict":
        baseline = json.loads((folder / "baseline.json").read_text())
        if baseline.get("fingerprint") != fingerprint or not baseline.get("passed"):
            raise RuntimeError("A passing baseline for these exact copies and endpoints is required")
    stop = threading.Event()
    workers = []
    results = []
    try:
        for case in config["cases"]:
            workers.append(server(case, stop))
        for variant in ["unrelated", "root", "child", "exec", "orphan"]:
            for case in config["cases"]:
                if variant == "unrelated":
                    command = [config["child"], "probe", case["host"], str(case["port"]), case["protocol"]]
                else:
                    command = [config["root"], variant, config["child"], case["host"],
                               str(case["port"]), case["protocol"]]
                observed = subprocess.run(command, capture_output=True, text=True, timeout=6)
                data = json.loads(observed.stdout)
                expected = mode == "baseline" or variant == "unrelated" or case["name"] == "allowed_tcp"
                passed = data["exchange"] == expected
                if variant == "orphan":
                    passed = passed and data["ppid"] == 1
                result = {"variant": variant, "case": case["name"], "expectedExchange": expected,
                          "passed": passed, **data}
                results.append(result)
                print(f"{'PASS' if passed else 'FAIL'} {variant:9} {case['name']:12} exchange={data['exchange']} ppid={data['ppid']}")
    finally:
        stop.set()
        for worker in workers:
            worker.join(timeout=2)
    passed = all(result["passed"] for result in results)
    write_json(folder / f"{mode}.json", {"fingerprint": fingerprint, "passed": passed, "results": results})
    if mode == "baseline":
        print("Baseline controls passed; strict interception is NOT verified." if passed else "Baseline failed; strict results cannot be accepted.")
    else:
        print("Strict local socket acceptance passed." if passed else "Strict acceptance FAILED; inspect interception, health, and selected policy.")
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["prepare", "baseline", "strict"])
    parser.add_argument("folder", type=lambda value: pathlib.Path(value).expanduser().resolve())
    parser.add_argument("--confirm-installed", action="store_true",
                        help="Confirm a legally signed provider is active with the exact generated root policy")
    args = parser.parse_args()
    if args.action == "prepare":
        prepare(args.folder)
        return 0
    if args.action == "strict" and not args.confirm_installed:
        parser.error("strict mode requires --confirm-installed; this tool never activates a provider")
    return run(args.folder, args.action)


if __name__ == "__main__":
    raise SystemExit(main())
