
《Linux内核完全剖析-基于0.12内核》一书详尽地解析了Linux 0.12版本的内核源码，并且在书的最后一章给出了调试源代码的方法和在不同平台上编译的修改等。阅读一些该书，并作一些理解上的笔迹，以备之后查阅。

#### Linux 0.12版本不足 ####

1. 没有调试代码（ptrace）
2. 专门进程等待队列
3. TCP/IP网络代码
4. 内存管理与现有Linux内核不同
5. ext2/ext3等文件系统

#### PC中的控制器和控制卡 ####

**RTC（Real Time Chip）**

**中断控制器**

8259A可编程中断控制芯片或其兼容芯片

**DMA控制器**

Intel 8237芯片或其兼容芯片

**定时/计数器**

Intel 8253/8254 可编程定时/计数器芯片，PIT（Programmable Interval Timer）

**键盘控制器**

**串行控制卡**

**显示控制**

**软盘和硬盘控制器**

#### 推荐参考书籍 ####

1. 《The C Programming Language》 Brian W. Kernighan和Dennis M. Ritchie
2. 《Unix操作系统设计》 M. J. Bach
3. 《操作系统：设计与实现》 Andrew S. Tanenbaum
4. 《Programming the 80386》 John H. Crawford



By Andy @2018-03-28 11:20:38
