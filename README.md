# Memory management optimaization for Qualcomm platform

English version:
- Remove QTI ActivityManager CUR_MAX_EMPTY_PROCESSES limit
- lowmemorykiller tend to keep tasks which adj < 950
- lowmemorykiller tend to remove tasks which adj >= 950
- Disable automatic kill when vmpressure >= 90
- Higher watermark_mid reduces the possibility of direct memory allocation
- Avoid swapping latency intensive processes, such as `system_server`, `systemui` and `launcher`
- Customizable ZRAM size, ranging from 0G to 6G, please edit `/sdcard/qti_mem_panel.txt` after install

中文版：
- 移除 QTI ActivityManager CUR_MAX_EMPTY_PROCESSES 最大空进程数量的限制
- lowmemorykiller 倾向于保留 adj < 950 的进程
- lowmemorykiller 倾向于结束 adj >= 950 的进程
- 禁止当`vmpressure >= 90`时激进地清理后台
- 较高的低内存水位线降低触发直接内存分配的概率
- 避免把延迟敏感的进程移入ZRAM，比如Android系统服务、Android系统界面和桌面
- 可自定义的ZRAM大小，较大的值会延长解压缩时间，范围从0GB到6GB，在安装后请修改`/sdcard/qti_mem_panel.txt`
