# GitHub 上传注意事项

> 本文档说明本项目上传 GitHub 前必须处理的文件、已核实的仓库状态，以及具体操作步骤。
> 仓库地址：https://github.com/fqqf11/ecommerce_behavior_analysis

---

## 一、绝对不能上传的文件

### 1.1 大文件清单（本项目实测）

| 文件 | 大小 | 当前状态 | 处理方式 |
|---|---|---|---|
| `data/2019.csv` | **520.6 MB** | 已被 `.gitignore` 忽略（未提交过） | 保持忽略 |
| `data/clean_2019.csv` | **7.5 MB** | **已被 Git 跟踪并提交** | 需从版本库移除 |
| `data/2019-Nov.csv` | 视下载而定 | 已被忽略 | 保持忽略 |

### 1.2 为什么 520 MB 的 2019.csv 很危险

GitHub 对仓库有明确限制：

- **单文件超过 100 MB 会被直接拒绝推送**（`this exceeds GitHub's file size limit of 100.00 MB`）；
- **超过 50 MB 会收到警告**；
- 一旦大文件进入提交历史，**即使后续删除文件，历史记录仍会保留该体积**，仓库会永久膨胀，只能通过 `git filter-repo` 或 BFG 重写历史才能清除；
- GitHub 仓库建议保持在 **1 GB 以内**，超过会收到限制提示。

**本项目现状（已核实）**：`data/2019.csv` 从未被提交，`.gitignore` 规则生效。这一项是安全的。

### 1.3 需要重点处理的 clean_2019.csv

**核实结果**：`data/clean_2019.csv`（7,800,965 字节）在初始提交 `4cef79c` 中已经被跟踪，目前仍存在于远程仓库。

**这个文件需要处理**，原因有两点：

1. **它是过期的残留数据**。该文件仅 66,190 行、13 个品类，是早期版本的产物；而当前所有 Notebook 实际读取的是 `out_data/allmonth_clean.csv`（16,519,793 行、523 个品类）。文件与代码已经不匹配。
2. **7.5 MB 的二进制数据文件不应进入仓库**。数据文件应通过下载脚本或说明文档引导获取，而不是直接提交。

**处理方式**（二选一）：

- 方案 A（推荐）：从版本库移除，加入 `.gitignore`，并在数据目录放置说明文件；
- 方案 B：替换为正确的清洗后数据 —— 但这会使仓库增大约 200 MB，不推荐。

---

## 二、建议忽略的文件类型

在本项目 `.gitignore` 基础上，建议补充以下规则：

```gitignore
# ===== 原始数据（体积过大，需自行下载）=====
data/
datas/
out_data/

# ===== 中间产物（可由代码重新生成）=====
*.csv
!requirements.txt

# ===== 压缩包（本地交付用）=====
*.zip

# ===== 虚拟环境（体积大、可重建）=====
.venv/
venv/
env/

# ===== Python 缓存与编译文件 =====
__pycache__/
*.py[cod]
*.egg-info/
.ipynb_checkpoints/

# ===== IDE / 编辑器配置 =====
.idea/
.vscode/
*.swp

# ===== 系统文件 =====
.DS_Store
Thumbs.db
```

> **注意**：如果使用 `*.csv` 通配规则，需要用 `!output/data/*.csv` 之类的反选规则保留你想要的结果文件。若希望保留 `output/data/` 下的指标结果（体积很小，合计约 20 KB），建议改为精确忽略数据目录：

```gitignore
data/
datas/
out_data/
*.zip
.venv/
venv/
env/
__pycache__/
*.py[cod]
*.egg-info/
.ipynb_checkpoints/
.idea/
.vscode/
*.swp
.DS_Store
Thumbs.db
```

---

## 三、Notebook 输出与隐私检查

### 3.1 Notebook 中的敏感信息

提交 `.ipynb` 前建议检查并清理：

1. **数据库连接信息**：项目中 SQL 脚本与 Notebook 使用了 MySQL。若代码中出现明文密码（如 `pymysql.connect(password='xxx')`），必须删除或改为环境变量读取；
2. **本地绝对路径**：如 `E:\\ecommerce_behavior_analysis\\...` 或 `C:\\Users\\...`，建议改为相对路径；
3. **Notebook 输出**：大段输出会让 diff 变得臃肿。如无必要可执行「Clear All Outputs」后提交。

检查命令：

```bash
# 搜索可能的密码/密钥
git grep -i -n -E "(password|passwd|secret|token|api[_-]?key|pymysql.connect)" -- "*.ipynb" "*.sql" "*.py"

# 搜索本地绝对路径
git grep -n -E "[A-Za-z]:\\\\" -- "*.ipynb" "*.sql" "*.py"
```

### 3.2 中文文件名问题

本项目目录与文件名包含中文（如 `code/python项目文件/`）。Git 默认会转义显示为八进制，可通过以下配置改善：

```bash
git config --global core.quotepath false
```

---

## 四、当前仓库状态（已核实）

```
远程仓库: https://github.com/fqqf11/ecommerce_behavior_analysis.git
当前分支: main
最新提交: 8723c13 README 新增数据来源说明（Kaggle 数据集）
```

### 4.1 未提交的改动

```
已删除:  README.md
已修改:  code/python项目文件/ 下的 7 个 Notebook
已修改:  code/sql项目文件/ 下的 5 个 SQL 脚本
已修改:  output/powerbl项目文件.pbix
未跟踪:  code/python项目文件/可视化输出.ipynb
未跟踪:  code/python项目文件/数据的合并与初步处理.ipynb
未跟踪:  output/电商用户行为数据分析报告.md
已忽略:  data/2019.csv
```

### 4.2 已跟踪但建议移除的文件

```
data/clean_2019.csv        （7.5 MB，过期数据，与当前代码不匹配）
```

---

## 五、操作步骤

### 步骤 1：处理过期数据文件

```bash
cd E:\ecommerce_behavior_analysis

# 从版本库移除（保留本地文件）
git rm --cached data/clean_2019.csv

# 加入忽略规则
Add-Content .gitignore "data/"
```

> **说明**：`git rm --cached` 只从 Git 索引移除，本地文件不会被删除。
> 该文件仍会保留在历史提交中（约 7.5 MB），如需彻底清理历史，参见第六节。

### 步骤 2：统一换行符（Windows 环境建议）

```bash
git config core.autocrlf true
```

### 步骤 3：添加所有改动

```bash
git add -A
git status
```

**在提交前，请务必确认 `git status` 中不包含：**

- `data/2019.csv`（520 MB）
- `data/clean_2019.csv`（7.5 MB）
- 任何 `.zip`、`.venv/`、`out_data/` 目录

### 步骤 4：提交

```bash
git commit -m "重构：更新为 5 个月全量数据分析，补充项目文档与报告"
```

### 步骤 5：推送到 GitHub

```bash
git push origin main
```

> 如果推送被拒绝并提示大文件超限，请检查第八节的排查方法。

---

## 六、如何彻底从历史中清除大文件

如果 `data/clean_2019.csv` 的历史体积需要清理（7.5 MB，非必须，但如果要清理 520 MB 的误提交则必须）：

### 方法 1：git filter-repo（推荐）

```bash
# 安装
pip install git-filter-repo

# 从全部历史中移除该文件
git filter-repo --path data/clean_2019.csv --invert-paths

# 强制推送（会重写远程历史，协作者需重新克隆）
git push origin --force --all
```

### 方法 2：BFG Repo-Cleaner

```bash
java -jar bfg.jar --delete-files clean_2019.csv
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push origin --force --all
```

> **警告**：重写历史会改变所有提交的 SHA 值，已克隆仓库的其他人必须重新克隆。个人项目可放心执行。

---

## 七、上传后验证

### 7.1 检查仓库体积

访问 `https://github.com/fqqf11/ecommerce_behavior_analysis`，确认：

- 首页文件列表中没有 `2019.csv`、`clean_2019.csv`；
- 仓库大小显示在合理范围（本项目代码与图表合计应远小于 10 MB）。

### 7.2 检查是否误提交大文件

```bash
# 列出仓库中最大的 10 个已跟踪文件
git ls-files | ForEach-Object { if (Test-Path $_) { [PSCustomObject]@{ Size = (Get-Item $_).Length; File = $_ } } } | Sort-Object Size -Descending | Select-Object -First 10 | Format-Table @{n='MB';e={[math]::Round($_.Size/1MB,2)}}, File -AutoSize
```

---

## 八、常见问题排查

### 8.1 推送被拒绝：文件过大

**报错**：
```
remote: error: File data/2019.csv is 520.00 MB; this exceeds GitHub's file size limit of 100.00 MB
```

**原因**：该文件已进入某个提交。`.gitignore` 只能阻止**未跟踪**文件被添加，对**已提交**的文件无效。

**解决**：
```bash
# 1. 从索引移除
git rm --cached data/2019.csv

# 2. 如果该文件只存在于最近一次提交（未推送）
git commit --amend

# 3. 如果存在于更早的提交，需重写历史
git filter-repo --path data/2019.csv --invert-paths
```

### 8.2 网络连接失败

**报错**：
```
fatal: unable to access 'https://github.com/...': schannel: AcquireCredentialsHandle failed
```

**可能原因与解决**：

1. **代理未启动**：本项目环境配置了本地代理（`http.proxy=http://127.0.0.1:7897`），需确认代理软件正在运行；
2. **证书校验问题**：可尝试切换 SSL 后端：
   ```bash
   git config --global http.sslBackend openssl
   ```
3. **凭据失效**：清除后重新登录：
   ```bash
   git config --global --unset credential.helper
   git config --global credential.helper manager
   ```

### 8.3 中文文件名显示为乱码

```bash
git config --global core.quotepath false
```

### 8.4 提交后发现敏感信息

如果密码或密钥已推送，**仅删除文件是不够的**，必须重写历史（见第六节），并**立即在对应平台更换该凭据**。

---

## 九、上传前检查清单

- [ ] `data/2019.csv`（520 MB）未被跟踪
- [ ] `data/clean_2019.csv`（7.5 MB）已从索引移除或确认要保留
- [ ] `.gitignore` 已包含 `data/`、`datas/`、`out_data/`、`*.zip`
- [ ] Notebook 中无明文数据库密码
- [ ] Notebook 中无本地绝对路径
- [ ] `requirements.txt` 已包含 `plotly`
- [ ] `README.md` 内容与实际数据范围一致（5 个月，非 11 月）
- [ ] `git status` 输出中无大文件
- [ ] 图表与指标结果 CSV 已包含（体积很小，建议保留）
