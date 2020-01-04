# Memory management optimaization for Qualcomm platform

## Feature

English version:
- Pure memory management optimization module, not containing other placebo and supporting mainstream Snapdragon platforms
- Solve the problem that the background can't hang even if the free memory is large, by removing QTI ActivityManager CUR_MAX_EMPTY_PROCESSES
- Disable automatic kill when vmpressure >= 90
- Reduce jitters under high memory pressure, adjust the trigger threshold and execution interval of lowmemorykiller, and keep the file page cache at a high level
- Reduce stucks under high memory pressure, reduce the probability of direct memory allocation via higher watermark_mid
- Fixed system common files in the file page cache, which significantly reduced the stucks caused by the key cache being swapped out due to page cache fluctuations
- Prohibit kernel memory recycling threads running on the prime core, avoid congesting the main thread that is interacting and reduce energy consumption
- Avoid swapping memory pages which are hard to compress to ZRAM, make the compression rate close to the ideal value of 2.8x
- Reduce swapping latency intensive processes, such as `system_server`, `systemui` and `launcher`
- Customizable ZRAM size and compression algorithm, ranging from 0G to 6G

中文版：
- 纯粹的内存管理优化模块，不含其它大杂烩，支持骁龙主流平台
- 解决即使剩余内存较多，后台也挂不住的问题，通过移除最大空进程数量(CUR_MAX_EMPTY_PROCESSES)的限制
- 禁止当`vmpressure >= 90`时自适应LMK激进地清理后台
- 减轻高内存压力下掉帧，调整lowmemorykiller的触发阈值和执行周期，使文件页面缓存保持在较高水平
- 减轻高内存压力下卡屏，较高的低内存水位线，降低触发直接内存分配的概率
- 将系统常用文件固定在文件页面缓存，显著降低由于页面缓存波动导致关键缓存被换出造成卡屏的情况
- 禁止内核内存回收线程运行在超大核，避免拥塞正在交互的主线程并且降低能耗
- 避免难以压缩的内存页移入ZRAM，使得压缩率接近理想值2.8x
- 降低把延迟敏感的进程移入ZRAM的程度，比如系统框架和桌面，通过MEMCG分组swapiness实现
- 可自定义的ZRAM大小和压缩算法，较大的值会延长解压缩时间，范围从0GB到6GB

## Requirement

- Magisk >= 17.0
- ARM v8a体系结构
- Android 6.0+

## Installation

- 安装模块重启，打开`/sdcard/Android/panel_qti_mem.txt`修改想要的ZRAM大小和压缩算法，重启后生效
- ZRAM大小默认值如下：
  - 3-4GB内存默认开启1GB的ZRAM
  - 6GB内存默认开启2GB的ZRAM
  - 8GB内存默认开启3GB的ZRAM
  - 12GB内存默认开启0GB的ZRAM
- 一加用户需要关闭“RamBoost启动加速”这个预读器
- 目前不支持ZSWAP

## FAQ

Q: 这是什么，是一键全优化吗？  
A: 这个是改善Android缓存进程管理的Magisk模块，避免过快地清除后台缓存进程并且改进低内存情况下的流畅度，不包含CPU调度优化之类的其他部分。  

Q: 我的设备能够使用这个吗？  
A: 本模块适用于高通64位硬件平台，并且Android版本不低于6.0，也就是说基本从2016年开始上市的设备都可以使用。  

Q: 不开启ZRAM是不是这个模块就没用了？  
A: ZRAM控制只是本模块的一小部分功能，不开启ZRAM使用本模块也能够改进低内存情况下的流畅度。  

Q: 我的设备有12GB的物理内存，还需要这个模块吗？  
A: 在某些设备上由于高通平台缓存进程数量限制比较严格，即使可用内存很多也会出现后台缓存被清除，本模块避免过快地清除后台缓存进程使得大内存得到充分利用。  

Q: 为什么在配置文件设置了ZRAM大小之后还是没开启ZRAM？  
A: 如果内核没有ZRAM功能本模块是不能够添加的。大部分官方内核都支持ZRAM，第三方内核不支持ZRAM的情况多一些。  

Q: ZRAM和swap是什么关系？  
A: ZRAM是swap分区的一种实现方式。在内核回收内存时，将非活动的匿名内存页换入块设备，被称为swap。这个块设备可以是独立的swap分区，可以是swapfile，也可以是ZRAM。ZRAM将换入的页面压缩后放到内存，所以相比传统的swap方式在读写延迟上低几个数量级，性能更好。  

Q: 为什么不使用swapfile？  
A: 存储在闪存或者磁盘这样外置存储的swapfile，读写延迟比ZRAM高几个数量级，这会显著降低流畅度所以不采用。  

Q: 这个跟SimpleLMK哪个好？  
A: 把Magisk模块跟内核模块对比是不合适的，把SimpleLMK跟LMK对比更加合适。SimpleLMK触发在直接内存分配，LMK触发在kswapd回收结束之后文件页面缓存低于阈值。SimpleLMK触发较晚，优点在于可以尽可能利用全部内存存放活动的匿名页和文件页面缓存，缺点在于文件页面缓存可能出现极低值造成比较长的停顿。LMK触发较早，优点在于主动地维持文件页面缓存水平不容易造成较长的停顿，缺点在于容易受缓存水平波动导致误清除后台缓存进程。本模块调整了LMK的执行代价，缓解了LMK容易受缓存水平波动的问题。  

Q: 为什么后台还是会掉？  
A: 物理内存资源是有限的，不可能满足无限的后台缓存需求。某些厂商可能额外做了后台缓存管理，例如利用LSTM预测来选择清理接下来最不可能使用的APP。  

Q: 为什么耗电变多了？  
A: 缓存进程本身是不增加耗电的，更多的页面交换增加的耗电十分有限。需要注意的是保活更多后台APP的同时，这些APP并非全都处于缓存休眠的状态，可能有不少服务在后台运行消耗电量。  

## Credit

@Doug Hoyte  
@卖火炬的小菇凉--改进在红米K20pro上的zram兼容性  
@钉宫--模块配置文件放到更容易找到的位置  
