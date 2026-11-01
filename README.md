# FlowWidget

Windows 桌面软件收纳箱和小组件。支持亚克力窗口、拖到桌面的磁贴、锁定和置顶。

## 环境

- Windows 10 / 11
- Python 3.10 或更高（推荐 3.13）

## 快速开始（Windows）

在项目根目录运行：

```powershell
.\setup-dev.ps1
.\start-dev.ps1
```

脚本会创建项目专用的 `.venv`，安装依赖，并从当前源码启动软件。

## 手动安装依赖

在 `FlowWidget` 目录下执行：

```powershell
python -m pip install -r requirements.txt
```

如果系统里有多个 Python，建议指定 3.13：

```powershell
py -3.13 -m pip install -r requirements.txt
```

如果要以可编辑 Python 包方式继续开发，也可以执行：

```powershell
python -m pip install -e .
```

## 启动

```powershell
python run.py
```

或：

```powershell
py -3.13 run.py
```

软件不要求从项目目录启动，源码中的 QML 和 RinUI 路径会按文件位置解析。用户设置保存在系统用户数据目录，不会混入源码包。

## 目录说明

- `run.py`：启动入口
- `pogget_float/`：应用逻辑和 QML 界面
- `pogget_float/Rin-UI-master/`：内置 Fluent 风格 UI 库（运行需要）

设置会写到当前用户目录，解压后直接运行即可，不必改配置。

如果需要使用外部 RinUI 目录，可设置 `POGGET_RINUI_PATH`；它既可以指向 `Rin-UI-master` 项目根目录，也可以直接指向里面的 `RinUI` 目录。
