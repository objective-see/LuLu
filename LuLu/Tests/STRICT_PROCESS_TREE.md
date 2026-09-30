# 嚴格程序樹規則

`scope = 3` 對選定的確切執行檔及已觀察到的後代預設拒絕，只放行明確例外。原有 `scope = 2` 保留子程序自身規則優先的行為。

## 設定 API

透過現有 `Rule init:`／`Rules add:save:` 建立永久規則。例如：

```objc
NSString* rootPath = [@"/absolute/path/to/claude" stringByResolvingSymlinksInPath];
NSDictionary* signingInfo = extractSigningInfo(NULL, rootPath, kSecCSDefaultFlags);
NSDictionary* info = @{
    KEY_PATH:rootPath,
    KEY_CS_INFO:signingInfo,
    KEY_TYPE:@RULE_TYPE_USER,
    KEY_SCOPE:@ACTION_SCOPE_PROCESS_TREE_STRICT,
    KEY_ACTION:@RULE_STATE_ALLOW,
    KEY_ENDPOINT_ADDR:@"127.0.0.1",
    KEY_ENDPOINT_PORT:@"17897",
    KEY_PROTOCOL:@(IPPROTO_TCP)
};
Rule* rule = [[Rule alloc] init:info];
BOOL added = (nil != rule) && [rules add:rule save:YES];
```

有正式簽章的根程序須提供 `KEY_CS_INFO`，包含有效狀態、簽章類別、`KEY_CS_ID` 及 `KEY_CS_TEAM_ID`；程序快照必須符合執行檔路徑、簽章識別及團隊。真正無簽章的執行檔可不附簽章資訊，使用確切路徑；沒有團隊識別的 ad-hoc 程式需固定 `KEY_CS_CDHASH`，更新執行檔後須重新核對雜湊。拒絕目錄萬用路徑、PID 期限及到期規則；端點只接受數值 IP、數值 CIDR／範圍或 `*`，不採用 URL／主機名稱作為實際目的地。

同一根程序內，較具體例外優先於 `*:*` 拒絕，同等具體度以拒絕為先。多個適用根程序的限制取交集；同一路徑的不同 Team／簽章 ID 或 CDHash 政策亦保留各自限制。子程序自身 Allow、全域 Allow 清單、允許 localhost／DNS 或被動 Allow 不能越過嚴格拒絕；例外仍受全域封鎖模式及封鎖清單約束。已暫停的連線在恢復時再次檢查。偏好未載入也不能越過已知嚴格限制；明確停用防火牆沿用原有語意。

新增、匯入或啟用嚴格規則需要健康的程序事件監察器；失敗不回報設定成功。正式部署須具備合法的 Endpoint Security／Network Extension 權限、簽章及系統授權。預設 `Extension.entitlements` 未加入 Endpoint Security entitlement，須由具資格的維護者取得授權並簽署擴充；否則嚴格規則無法啟用。

## 可重跑的原碼驗證

```sh
LuLu/Tests/run_strict_process_tree_tests.sh
LuLu/Tests/run_strict_rule_format_tests.sh
LuLu/Tests/run_process_tree_tracker_tests.sh
```

政策整合測試直接編譯及執行正式 `Rule.m`、`Rules.m`、`ProcessTreeTracker.m`、`FilterDataProvider.m`、`XPCDaemon.m` 和比對工具函式。替身只提供記憶體偏好、程序查詢、XPC、核心事件輸入及框架恢復連線的觀察點；不複製規則比對或判決程式。另直接執行 XPC profile 切換流程，以記憶體的規則載入結果驗證失敗回復及成功通知。編譯及執行檔放於一次性暫存目錄，退出即清除。

涵蓋 TCP `127.0.0.1:17897` 例外、其他 IPv4／IPv6／loopback／UDP／DNS 拒絕、子程序自身 Allow、父程序退出與重新收養、exec、PID 版本重用、簽章／路徑隔離、恢復已暫停連線與快取清除、profile 啟用失敗回復、監察器失效、規則交集及原有 scope 2 優先序。這些測試不等同已安裝系統擴充的攔截驗收。

## 系統 socket 驗收工具

以下工具只建立兩份小型 canary、實際讀取的 ad-hoc CDHash、測試資料及本機 echo 端點，使用臨時連接埠；不寫入 LuLu 規則、不啟動 provider、不改代理或存取公網。

```sh
python3 LuLu/Tests/strict_process_tree/system_acceptance.py prepare /tmp/lulu-canary
python3 LuLu/Tests/strict_process_tree/system_acceptance.py baseline /tmp/lulu-canary
```

`prepare` 顯示唯一選定根程序及 TCP 例外端點，並核對本機簽章與 CDHash；`rule-info.json` 提供 `Rule init:` 的資料，包括外部子程序自身 Allow，並非可直接匯入的規則封存。baseline 必須證實所有 IPv4／IPv6 TCP／UDP 端點可往返，包含子程序、exec、父程序及中間程序已退出的孫程序。

在合法簽署版本中設定這份確切政策並確認服務、事件監察與規則生效後，才啟動選定的 canary：

```sh
python3 LuLu/Tests/strict_process_tree/system_acceptance.py strict /tmp/lulu-canary --confirm-installed
```

strict 模式核對相同執行檔及端點的 baseline，要求根程序／child／exec／orphan 只成功往返指定 TCP 端點；無關程序須繼續全部成功。若未攔截而所有連線仍成功，會失敗。結果存於 `baseline.json`／`strict.json`；部署結論仍須配合 provider 健康及日誌。測試完成及不再需要這些規則後，可刪除整個 canary 目錄。

## 覆蓋邊界

核心 audit token 的 PID 加執行版本識別程序；已捕捉的祖先快照保留於後代，父程序退出不改以 launchd 代替原祖先。監察失效、事件遺失或容量耗盡時，已知受限制的程序拒絕連線例外。

啟動監察前已存在的後代、未捕捉 fork／exec、被 SDK 預設靜音的 AUTH 事件，以及 fork 通知先後的競態，可能留下無法歸屬的程序。無法知道它屬於選定根程序時，不會把嚴格政策套用到所有其他軟體；因此不能承諾無缺口的程序樹防逃逸。同一 tracker 的停止／重新啟動保留已捕捉歷史，但服務程序重新啟動會失去記憶體歷史。新政策不回溯重新判決已放行的連線，驗收應在政策啟用後重新啟動選定程序。NE／ES 無法歸屬的委託流量、代發 DNS 及 VM 內流量未驗證；完整系統保證尚需合法安裝後的事件排序、丟失及真實流量驗收。
