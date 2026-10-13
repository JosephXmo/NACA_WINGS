# NACA_WINGS

一个用于计算和绘制 **NACA 四位数翼型截面**的小型学习项目，使用 Fortran 生成坐标、Python 绘图。本仓库保留原始实现，供 GitHub 归档、阅读和复现实验。

## 项目内容

- `NACAWINGS.F90`：解析翼型编号，计算厚度分布、中弧线及上下表面坐标，输出数据文件。
- `draw_wing.py`：按固定宽度读取坐标文件，使用 Matplotlib 绘制翼型。

计算采用归一化弦长 `c = 1`、10,000 个均匀采样点和单精度浮点数。厚度公式的末项系数为 `-0.1015`，因此尾缘保留有限厚度。

例如，`2412` 表示最大弯度为弦长的 2%，最大弯度位于距前缘 40% 弦长处，最大厚度为弦长的 12%。

## 环境要求

- 支持 Fortran 2008 的编译器（下文使用 GNU Fortran / `gfortran`）。
- Python 3，以及 `pandas`、`matplotlib`。
- 交互绘图需要可用的图形界面和 Matplotlib 后端。

macOS 可通过 Homebrew 安装编译器：

```sh
brew install gcc
```

Ubuntu / Debian 可使用：

```sh
sudo apt install gfortran python3 python3-venv
```

在仓库根目录创建 Python 环境并安装绘图依赖：

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install pandas matplotlib
```

## 运行

所有命令均在仓库根目录执行，因为程序使用当前工作目录中的相对路径。

### 生成坐标

```sh
gfortran -std=f2008 -O3 NACAWINGS.F90 -o nacawings
./nacawings
```

按提示输入 `2412`，或直接通过标准输入传入编号：

```sh
printf '2412\n' | ./nacawings
```

程序生成以下文件；再次运行会覆盖同名文件：

| 文件 | 内容 |
| --- | --- |
| `RESULTS.DAT` | 两行表头后为 10,000 行坐标，列顺序为 `XU YU XL YL`，分别对应上下表面的横纵坐标。 |
| `PROFILE.DAT` | 翼型参数与分布数据；实际数据列顺序为 `X YT YC`，现有表头误写为 `X YC YT`。 |

### 绘制翼型

```sh
python draw_wing.py
```

脚本顶部可调整：

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `NACA_ID` | `2412` | 没有 `RESULTS.DAT` 时，用于生成翼型的编号。 |
| `UNIFORM_CURVE` | `True` | 将上下表面连接成一条曲线；设为 `False` 时分别绘制，并显示坐标轴标签和网格。 |
| `CLEAN` | `True` | 脚本自行生成数据后，关闭图窗时删除 `RESULTS.DAT`、`PROFILE.DAT` 和 `nacawings`；需要保留时设为 `False`。 |

若不存在 `nacawings`，脚本会调用 `gfortran -O3 -march=native` 自动编译。若已有 `RESULTS.DAT`，脚本会直接读取它并关闭自动清理；修改 `NACA_ID` 不会刷新已有数据。需要更换翼型时，先运行 Fortran 程序重新生成数据。

## 已知限制

- 当前实现将 `m = 0` 或 `p = 0` 视为无效参数，并以 `-9999.99` 填充分布数据，因此不正确支持 `0012` 等对称翼型。
- `PROFILE.DAT` 的 `YC` / `YT` 表头顺序与数据不一致；最大弯度位置输出的是第二位数字，例如 `2412` 显示 `4%`，其实际含义应为 `40%`。
- 输入编号没有完整范围检查，Python 脚本也没有完整处理编译或执行失败的情况。建议使用已知有效的有弯度四位数翼型。
- 本项目计算二维几何截面，不提供升阻力、流场或三维机翼分析。

## 许可证

本项目使用 [MIT License](LICENSE)，版权归 Sibo Qiu 所有。
