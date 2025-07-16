#!/bin/bash
set -e

# 定义变量
ARCH=$(uname -m)
CONDA_INSTALL_DIR="$HOME/miniconda" # Miniconda安装路径
PYTHON_VERSION="3.11"               # Python版本
# 根据架构调整Conda安装路径和环境名称
if [ "$ARCH" == "x86_64" ]; then
    ENV_NAME="pyspark_env_py311_x86_64"
    REQUIREMENTS_FILE="requirements.x86_64.txt"
    MINICONDA_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py311_25.5.1-0-Linux-x86_64.sh"
elif [ "$ARCH" == "aarch64" ]; then
    ENV_NAME="pyspark_env_py311_arm64"
    REQUIREMENTS_FILE="requirements.arm64.txt"
    MINICONDA_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py311_25.5.1-0-Linux-aarch64.sh"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
ARCHIVE_NAME="${ENV_NAME}.zip"      # 打包后的归档文件名称
ARCHIVE_ALIAS="pyspark_env"         # 在Spark中引用的别名

# 1. 下载并安装Conda (这里以Miniconda为例)
echo "1. Downloading and installing Miniconda..."
MINICONDA_INSTALLER="miniconda_installer.sh"

wget "$MINICONDA_URL" -O "$MINICONDA_INSTALLER"
chmod +x "$MINICONDA_INSTALLER"
./"$MINICONDA_INSTALLER" -b -p "$CONDA_INSTALL_DIR"
rm "$MINICONDA_INSTALLER"

# 初始化Conda
source "$CONDA_INSTALL_DIR/bin/activate"

# To accept a channel's Terms of Service, run the following command:
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# 2. 使用conda创建独立环境，并安装对应版本的Python
echo "2. Creating Conda environment '$ENV_NAME' with Python $PYTHON_VERSION..."
conda create -y -n "$ENV_NAME" python="$PYTHON_VERSION"

# 激活新创建的环境
conda activate "$ENV_NAME"

# 3. 根据requirements安装pip包
# 假设你的requirements.txt文件在当前目录下
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "3. Installing pip packages from $REQUIREMENTS_FILE..."
    pip install --upgrade pip
    pip install -r "$REQUIREMENTS_FILE"
else
    echo "WARNING: $REQUIREMENTS_FILE not found. Skipping pip package installation."
    echo "Please create a $REQUIREMENTS_FILE with your dependencies, e.g.:"
    echo "pyspark==3.4.1"
    echo "pandas==2.0.3"
    echo "numpy==1.25.1"
fi

# 确保 conda-pack 已安装
echo "Ensuring conda-pack is installed in '$ENV_NAME'..."
conda install -y conda-pack
 
# 4. 使用 conda-pack 将conda的Python环境打包
echo "4. Packaging Conda environment '$ENV_NAME' using conda-pack..."
 
# 打包命令
# --output 指定输出文件
# --compress 指定压缩算法，lz4或gzip，lz4更快但可能略大
# --ignore-existing 忽略已存在的同名输出文件
conda pack -n "$ENV_NAME" -o "$ARCHIVE_NAME" --compress gzip --ignore-existing
 
echo "Package created: $(pwd)/$ARCHIVE_NAME"
echo "You can now use this archive with Spark submit:"
echo "spark-submit \\"
echo "  --master yarn \\"
echo "  --deploy-mode cluster \\"
echo "  --archives hdfs:///path/to/your/$(pwd)/$ARCHIVE_NAME#$ARCHIVE_ALIAS \\"
echo "  --conf spark.executorEnv.PYTHONPATH=$ARCHIVE_ALIAS/lib/python${PYTHON_VERSION%.*}/site-packages:$ARCHIVE_ALIAS/__pycache__ \\"
echo "  your_pyspark_app.py"
 
echo "Done."