# LuLu Tests

Standalone test suites, each compiled and run via its own script.

```bash
# Run a suite
./run_passive_mode_tests.sh
./run_wildcard_rule_tests.sh
```

---

# Passive Mode Improvements Tests

Tests for the passive mode FQDN rule creation improvements.

## What's Tested

### 🎯 Domain Name Prioritization
- Prioritizes `flow.URL.host` over `flow.remoteHostname` over `remoteEndpoint.hostname`
- Ensures rules use domain names like `github.com` instead of IP addresses like `140.82.112.3`

### 🎨 Smart Port Display  
- Hides common ports (80, 443) for cleaner UI display
- Shows uncommon ports (8080, 3000, etc.) to highlight important information
- Preserves full data internally for precise filtering

### 🔗 End-to-End Integration
- Validates complete flow from network traffic to final rule display
- Tests real-world scenarios with complex URLs and various port configurations

## Running Tests

```bash
# Run the complete test suite
./run_passive_mode_tests.sh
```

## Test Results

✅ **9/9 tests pass** covering all functionality

### Before/After Examples

| Before (IP-based) | After (Domain-based) |
|------------------|---------------------|
| `140.82.112.3:443` | `github.com` |
| `52.36.184.210:443` | `api.slack.com` |
| `127.0.0.1:8080` | `localhost:8080` |

## Files

- `test_passive_mode_improvements.m` - Comprehensive test suite
- `run_passive_mode_tests.sh` - Build and run script

---

# Wildcard Rule Tests

Tests for rule paths that contain wildcards, e.g. `/Users/*/.vscode/extensions/foo-*/bar`.

Unlike the suite above, these compile against the real implementation
(`../Shared/WildcardPath.m`), so they exercise the same code the app and extension use.

## What's Tested

### 🧭 Rule Classification (`isWildcardPath`)
- Tells wildcard paths apart from the rule types that already exist: the global rule (`*`) and directory rules (`/dir/*`), both of which keep their own (cheaper) matching
- A directory rule with a `*` higher up (e.g. `/Users/*/Library/Foo/*`) isn't prefix-matchable, so it's a wildcard rule
- Ignores paths that can't name a binary (relative, empty, nil)

### ✂️ Literal Prefix (`wildcardPathPrefix`)
- The leading literal portion, up to the first wildcard — used as a cheap pre-filter on the matching hot path, and to pick the rule's icon in the UI

### 🎯 Matching (`wildcardPathMatch`)
- The real examples from issue #176: a VS Code extension whose path changes on every update, and a Terraform plugin under a pair of random directories
- A `*` matches within a single path component and never across a `/`, so a rule can't quietly widen to everything nested below it
- Patterns are anchored: they match the whole path, not a prefix of it

## Running Tests

```bash
# Run the complete test suite
./run_wildcard_rule_tests.sh
```

## Test Results

✅ **31/31 tests pass**

### Examples

| Rule path | Matches |
|-----------|---------|
| `/Users/*/.vscode/extensions/ms-vsliveshare.vsliveshare-*/dotnet_modules` | every version of the extension, for any user |
| `/tmp/*/*/*/.terraform/plugins/darwin_amd64/terraform-provider-aws_v2.50.0_x4` | the plugin, under its randomly-named directories |
| `/Users/*/foo` | `/Users/user/foo`, but *not* `/Users/user/nested/foo` |

## Files

- `test_wildcard_rules.m` - Test suite
- `run_wildcard_rule_tests.sh` - Build and run script
