#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
cd "$PKG_PATH" || { echo "Failed to cd $PKG_PATH"; exit 1; }

echo "当前编译目标: ${WRT_CONFIG}"
echo "当前工作目录: $(pwd)"

# ============================================
# 预置 HomeProxy 数据
# ============================================
if [ -d *"homeproxy"* ]; then
    echo " "
    
    HP_RULE="surge"
    HP_PATH="homeproxy/root/etc/homeproxy"
    
    rm -rf ./$HP_PATH/resources/*
    
    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
    cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")
    
    echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
    mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/
    
    cd .. && rm -rf ./$HP_RULE/
    
    cd "$PKG_PATH" && echo "homeproxy data has been updated!"
fi

# ============================================
# 修改 argon 主题字体和颜色
# ============================================
if [ -d *"luci-theme-argon"* ]; then
    echo " " && cd ./luci-theme-argon/
    
    sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon
    
    cd "$PKG_PATH" && echo "theme-argon has been fixed!"
fi

# ============================================
# 修改 aurora 菜单式样
# ============================================
if [ -d *"luci-app-aurora-config"* ]; then
    echo " " && cd ./luci-app-aurora-config/
    
    sed -i "s/nav_type '.*'/nav_type 'dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")
    
    cd "$PKG_PATH" && echo "theme-aurora has been fixed!"
fi

# ============================================
# 修改 mini-diskmanager 菜单位置
# ============================================
if [ -d *"luci-app-mini-diskmanager"* ]; then
    echo " " && cd ./luci-app-mini-diskmanager/
    
    sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json
    
    cd "$PKG_PATH" && echo "mini-diskmanager has been fixed!"
fi

# ============================================
# 修复 TailScale 配置文件冲突
# ============================================
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
    echo " "
    
    sed -i '/\/files/d' "$TS_FILE"
    
    cd "$PKG_PATH" && echo "tailscale has been fixed!"
fi

# ============================================
# 修复 Rust 编译失败
# ============================================
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
    echo " "
    
    sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
    
    cd "$PKG_PATH" && echo "rust has been fixed!"
fi

# ============================================
# Redmi AX6000 ubootmod 同时生成 .bin 格式
# 只在编译 mediatek/filogic 相关目标时才执行
# ============================================
if [[ "${WRT_CONFIG}" == *"MEDIATEK"* ]] || [[ "${WRT_CONFIG}" == *"FILOGIC"* ]] || [[ "${WRT_CONFIG}" == *"AX6000"* ]]; then
    echo "正在修改 Redmi AX6000 ubootmod 镜像配置..."
    
    # 当前在 wrt/package/ 目录下，filogic.mk 的正确相对路径
    FILOGIC_MK="../target/linux/mediatek/image/filogic.mk"
    
    if [ -f "$FILOGIC_MK" ]; then
        cp "$FILOGIC_MK" "${FILOGIC_MK}.bak"
        
        awk '
        /define Device\/xiaomi_redmi-router-ax6000-ubootmod/ {
            in_device = 1
        }
        in_device && /IMAGES := sysupgrade\.itb/ {
            print "  IMAGES := sysupgrade.itb sysupgrade.bin"
            next
        }
        in_device && /IMAGE\/sysupgrade\.itb := append-kernel/ {
            print
            print "  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata"
            next
        }
        /^endef/ && in_device {
            in_device = 0
        }
        { print }
        ' "$FILOGIC_MK" > filogic.mk.tmp && mv filogic.mk.tmp "$FILOGIC_MK"
        
        echo "验证修改结果："
        grep -A 12 "define Device/xiaomi_redmi-router-ax6000-ubootmod" "$FILOGIC_MK"
        echo "AX6000 ubootmod image format has been changed to .bin!"
    else
        echo "filogic.mk 不存在于 $FILOGIC_MK，跳过 AX6000 修改"
    fi
else
    echo "当前目标为 ${WRT_CONFIG}，跳过 mediatek 修改"
fi
