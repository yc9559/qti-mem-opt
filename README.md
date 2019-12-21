# Memory management optimaization for Qualcomm platform

## Feature

English version:
- Pure memory management optimization module, not containing other placebo and supporting mainstream Snapdragon platforms
- Solve the problem that the background can't hang even if the free memory is large, by removing QTI ActivityManager CUR_MAX_EMPTY_PROCESSES
- Disable automatic kill when vmpressure >= 90
- Reduce jitters under high memory pressure, lowmemorykiller tends to kill the process of adj> = 950, so that the file page cache is kept at a high level
- Reduce stucks under high memory pressure, reduce the probability of direct memory allocation via higher watermark_mid
- Avoid swapping memory pages which are hard to compress to ZRAM, make the compression rate close to the ideal value of 2.8x
- ~~Avoid swapping latency intensive processes, such as `system_server`, `systemui` and `launcher`~~
- Customizable ZRAM size, ranging from 0G to 6G, please edit `/sdcard/qti_mem_panel.txt` after install

中文版：
- 纯粹的内存管理优化模块，不含其它大杂烩，支持骁龙主流平台
- 解决即使剩余内存较多，后台也挂不住的问题，通过移除最大空进程数量(CUR_MAX_EMPTY_PROCESSES)的限制
- 禁止当`vmpressure >= 90`时自适应LMK激进地清理后台
- 减轻高内存压力下掉帧，lowmemorykiller 倾向于结束 adj >= 950 的进程，使文件页面缓存保持在较高水平
- 减轻高内存压力下卡屏，较高的低内存水位线，降低触发直接内存分配的概率
- 避免难以压缩的内存页移入ZRAM，使得压缩率接近理想值2.8x
- ~~避免把延迟敏感的进程移入ZRAM，比如系统框架和桌面，通过MEMCG分组swapiness实现~~
- 可自定义的ZRAM大小，较大的值会延长解压缩时间，范围从0GB到6GB，在安装后请修改`/sdcard/qti_mem_panel.txt`

## Note

- Magisk >= 17.0
- 安装模块重启，打开/sdcard/qti_mem_panel.txt修改想要的ZRAM大小，重启后生效
- ZRAM大小默认值，也可自定义
  - 3GB内存推荐1.0GB的ZRAM
  - 4GB内存推荐1.0GB的ZRAM
  - 6GB内存推荐1.5GB的ZRAM
  - 8GB内存推荐2.5GB的ZRAM
  - 12GB内存推荐0GB的ZRAM
- 一加用户需要关闭“RamBoost启动加速”这个预读器
- 目前不支持ZSWAP
