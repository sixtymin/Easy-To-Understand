
## QEMU用户文档 ##

基于2.11.93版本

#### 介绍 ####

Qemu运行非常快！处理器模拟器使用动态转换达到了非常高的模拟速度。

Qemu有两个操作模式：

* 完整系统模拟：在这个模式下，Qemu模拟一个完整的系统（例如一个PC），包括一个或多个处理器，各种外围设备。在无需启动PC的情况下，它可以用来启动不同的操作系统或者调试系统代码。
* 用户模式模拟：这种模式下，Qemu可以在一种CPU上启动为另外一种CPU编译的进程模块。它可以用于加载Wine Windows API模拟器或者完成跨平台编译和跨平台调试。

Qemu有如下特点：

* Qemu在没有主机内核驱动支持下运行，并且性能可观。它使用动态转换为本地代码来达到合理的运行速度，并且支持自修改代码和准确地异常处理。
* 它可以一直到集中操作系统平台上（GNU/Linux，*BSD，Mac OS X，Windows）和不同架构上。
* 它可以为FPU实现准确的软件模拟。

Qemu用户模式模拟器有如下的特点：

* 通用的Linux系统调用转换，包括大多数的ioctls。
* 使用本地CPU clone()模拟clone()，使用Linux调度器调度线程。
* 通过将重新映射主机信号为目标信号来达到准确的信号处理。

Qemu完整系统模拟有如下的特点：

* Qemu使用完整的软件MMU实现最大可移植性
* Qemu可以有选择地使用内核内的加速器，如KVM。加速器以本地代码形式执行大多数的客户机代码，而胜于的机器部分使用模拟实现
* 各种硬件可以通过模拟实现，主机设备（例如串口，并口，USB，磁盘驱动等）可以透明地被客户操作系统使用。主机设备穿透可以用于与外部物理设备直接通信（例如webcam，猫或磁带驱动器等）。
* 支持对称多处理（SMP）。当前内核内的加速器要求使用不止一个主机的CPU用于模拟。

#### QEMU PC系统模拟器 ####

**1. 介绍**

Qemu PC系统模拟器模拟如下的外围设备：

* i440FX主机PCI桥和PIIX3 PCI到ISA桥
* Cirrus CLGD 5446 PCI VGA卡或带有Bochs VESA阔啊栈的VGA卡（硬件级别，包括所有非标准模式）
* PS/2鼠标和键盘
* 2 PCI IDE接口，支持硬盘和CD-ROM
* 软盘
* PCI和ISA网卡
* 串口
* IPMI BMC，内置或外置
* Creative SoundBlaster 16位声卡
* ENSONIQ AudioPIC ES1370声卡
* Intel 82801AA AC97音频兼容声卡
* Intel HD音频控制器和HDA解码
* Adlib（OPL2） - Yamaha YM3812兼容芯片
* Gravis Ultasound GF1声卡
* CS4231A兼容声卡
* PCI UHCI，OHCI，EHCI 或XHCI USB控制器和虚拟USB-1.1 hub

SMP支持高达255个CPU。Qemu使用SeaBios项目中的PC BIOS，并且自持Plex86/Bochs LGPL VGA BIOS。Qemu支持Tatsuyuki Satoh的YM3812模拟。Qemu使用Tibor "TS" Schutz的GUS模拟。注意，默认情况下GUS和并口共用IRQ7，因此Qemu必须设置在有GUS时不能有并口使用。

```qemu-system-i3====86 dos.img -soundhw gus -parallel none```

或者使用另外一个可选的方案：

```qemu-system-i386 dos.img -device gus,irq=5```

CS6231A是用于Windows声音系统的芯片，由GUSMAX生产。

**2. 快速上手**

下载并解压Linux镜像（linux.img），然后输入：`qemu-system-i386 linux.img`。然后就可以看到Linux引导并显示提示符。

**3. 使用方法**

`qemu-system-i386 [options] [disk_image]`是基本的使用格式。disk\_image是原始的硬盘镜像用户IDE硬盘0。一些情况下并不需要磁盘镜像。

**标准选项：**

_-h_: 显示帮助并退出。

_-version_: 显示版本信息并退出。

_-machine [type=] name[,prop=value...]_: 用于指定所模拟的机器。那么即表示机器类型，使用`qemu-system-i386 -machine help`可以列出当前版本所支持的机器类型。主要是为了在发布过程中，高版本Qemu所默认模拟的机器类型在变化，导致旧版本升级后，用户的模拟环境可能出现问题。为了兼容性，设置该参数后可以让高版本Qemu一样模拟用户的环境中指定机器类型。更多参数参看英文文档。

_-cpu model_: 选择CPU模型，使用`qemu-system-i386 -cpu help`可以列举出支持CPU模型列表，以及额外的特征选项。

_-accel name[,prop=value...]_: 这个选项用于开启加速器。依赖于目标机器架构，可能kvm，xen，hax等可用。默认情况下使用tcg。如果有多个加速器可用，那么可以指定多个，如果前一个初始化失败，会使用指定的下一个加速器。更多的-cpu参数参看英文原文。

_-smp [cpus=]n[,cores-cores][,threads=threads][,sockets=sockets][,maxcpus=maxcpus]_: 用个CPU模拟SMP系统。在PC上可以支持高达255个CPU。在Sparc 32机器上，Linux限制可用CPU为4。在PC机上，socket的核心数，每个核心的线程数以及总的sockets数都可以指定。如果不给出其中的值，它们会被按照默认值进行计算。如果任意三个参数指定，则可以忽略CPU个数参数n。maxcpus指定热插入CPU的最大数。

_-numa_: NUMA架构设置，这个设置一般情况下不用，而是在模拟这种架构时才会用到。不做详细解析。

_-add-fd fd=fd,set=set[,opaque=opaque]_: 增加一个文件描述符到fd集合，具体的选项可以参考英文文档

_-global driver.prop=value_: 设置驱动器属性的默认值。例如`qemu-system-i386 -global ide-hd.physical_block_size=4096 disk-image.img`。

_-boot [order=drivers][,once=drivers][,memu=on|off][,splash=sp_name][,splash-time=sp_time][,reboot-timeout=rb\_timeout][,strict=on|off]_: 指定引导顺序，参数divers是驱动字符的字符串。有效的驱动字符依赖于目标架构。X86的PC使用a,b(floppy 1和2)，c（第一个硬盘），d（第一个CD-ROM），n-p（从网络设备1-4进入引导）。默认引导设备是磁盘。第一次启动时使用特殊的引导顺序通过once参数指定。注意order或once参数不应该和bootindex属性一起使用。可选的引导菜单或提示可以使用`menu=on`开启，当然需要固件或BIOS支持。默认是不开启可选引导。splash图片可以传递给bios，使用户可以指定它作为logo，这个功能需要固件或BIOS支持，并且指定选项splash设置和menu=on设置。当前用于X86系统的Seabios支持这个功能。限制：splash文件需要是24位真彩格式的jpeg文件或BMP文件。分辨率应该被SVGA模式支持，推荐的是320X240，640X480，800X640。

超时可以传递给BIOS，客户机在引导失败后会暂停rb\_timeout毫秒，然后在重新引导。如果参数值为-1，则客户机不再引导。默认值为-1，当前X86系统的Seabios支持该功能。如果固件支持严格引导，使用`strict=on`开启精确引导。这个仅仅在引导优先级通过bootindex修改后才会有影响，默认非精确引导模式。

```
# 首先尝试从网络引导，然后再从硬盘引导
qemu-system-i386 -boot order=nc
# 首先从CD-ROM引导，在重新引导时切回默认引导顺序
qemu-system-i386 -boot once=d
# 引导时使用splash图片，停留5秒
qemu-system-i386 -boot menu=on,splash=/root/boot.bmp,splash-time=5000
```

_-m [size=]megs[,slots=n,maxmem=size]_: 设置客户机RAM大小为megs兆字节。默认是128M字节。可选的支持后缀M或G，分别用于表示数值为兆字节或吉字节。可选参数slots，maxmem可以用于设置可插入内存槽和最大内存量。注意maxmem参数值必须是页面大小对齐。

如配制`qemu-system-i386 -m 1G,slot=3,maxmem=4G`定义客户机启动RAM大小为1G，创建三个热插拔内存槽，设置客户机内存最多达到4GB。

_-mem-path path_: 从path目录临时创建的文件中为客户机分配RAM。

_-mem-prealloc_: 使用-mem-path参数时预先分配内存。

_-k language_: 使用键盘的布局语言，例如fr代表French。这个选项仅仅在不需要获取PC键盘码的情况下（比如在Macs，一些X11服务器或VNC或多视窗显示）。通常不需要设置这个参数。默认是en-us。

_-audio-help_: 显示音频子系统帮助，列举可用的驱动器，可调节参数。

_soundhw card1[,card2,...] or -soundhw all_: 开启音频和选择的音频硬件，使用help打印所有可用音频硬件。例如`qemu-system-i386 -soundhw sb16,adlib disk.img`。

_-ballon virtio[,addr=addr]_: 开启virtio balloon设备，可选PCI地址addr。不鼓励使用该参数，而要用--device virtio-balloon代替

_-device driver[,prop[=value][,]]_: 增加设备的驱动参数，driver.prop=value设置驱动属性。可选的属性依赖于设备驱动。获取指定设备的帮助可以使用 `qemu-system-i386 -device help`和`qemu-system-i386 -device driver,help`。
_-name name_: 设置客户机的名字，这个名字会显示在窗口上。这个窗口对于VNC服务器比较有用。

_-uuid uuid_: 用于设置系统的UUID。

**块设备选项**:

_-fda file/-fdb file_: 使用文件file当作软盘0/1映像。
_-hda file/-hdb file/-hdc file/-hdd file_: 使用文件file作为硬盘0，1，2，3的映像

_cdrom file_: 使用文件file当作CD-ROM映像，-hdc和-cdrom不能同时使用。

_-blockdev option[,option[,option[,...]]]_: 定义一个新的块设备节点。详细可以参考英文文档。

_-drive option[,option[,option[,...]]]_: 定义一个新的驱动器。这包括创建一个块设备驱动器节点，通常作为定义对应的-blockdev和-device选项的简写。

_-mtdblock file_: 使用文件file作为板上Flash内存映像

其他的块设备选项参考英文文档吧，普通使用用不上这些选项。

**USB选项**:

_usb_: 开启USB驱动（如果默认并不使用USB）。

_-usbdevice devname_: 用于加入USB设备devname，这个选项已经过时，使用`-device usb-...`代替。

**显示选项**:

_-display type_: 选择使用的显示类型，可选的参数值有：sdl 通过SDL显示视频输出（通常在独立的图像窗口）。curses 通过多视窗方式显示视频输出。Qemu可以使用多视窗/非多视窗接口显示输出。如果图形设备是图形模式，或者它不支持文本模式那就什么也不显示了。通常VGA设备模型支持文本模式。none 不要显示设备输出。gtk表示在GTK窗口中显示视频输出，这个接口提供了下拉菜单和其他的UI元素来进行配置。vnc在显示参数arg上启动一个VNC服务器。

_-nographic_: 通常，Qemu编译为带有图形窗口的支持形式，它通过客户图形窗口或客户控制台显示输出，并且在窗口中显示Qemu监控器。如果使用这个选项，那么完全禁用了图形输出，这样Qemu就变成了简单的命令行应用程序。模拟的串口会被重定向到控制台，与监控器共用（除非被设置显示重定向到其他地方）。因此，仍然可以使用Qemu通过串口控制台调试Linux内核。使用`C-a h`显示帮助，用于在控制台和监控器之间切换。

_-alt-grab_: 使用`Ctrl-Alt-Shift`来抓取鼠标（代替`Ctrl-Alt`）。这会影响到特殊的快捷键。

_-ctrl-grab_: 使用`Right-Ctrl`来抓取鼠标（代替`Ctrl-Alt`）。这会影响到特殊的快捷键。

_-no-quit_: 禁用SDL窗口关闭。

_-sdl_: 开启SDL。

_-spice option[,option[,...]]_: 开启spice远程桌面协议。

_-vga type_: 选择要模拟的VGA卡类型，可用值如下：cirrus表示Cirrus Logic GD5446卡。std表示标准的VGA卡，带有Bochs VBE扩展。如果客户操作系统支持VESA 2.0 VBE扩展，并且你想要使用高分别率，那么就要使用这个选项了。这个类型是Qemu2.2之后默认设置。vmware表示VMWare SVGA-II兼容适配器。qxl表示QXL虚拟图形卡。

_-full-screen_: 在全屏中启动。

**仅用于i386目标系统**

这个需要时再查阅，并非常用选项。

**网络选项**

_-nic [tap|bridge|user|l2tpv3|vde|netmap|vhost-user|socket][,...][,mac=macaddr][,model=mn]_: 选项是用于配置板载客户机NIC硬件和主机网络后端的简写形式。主机的后端选项和-netdev中的一样。客户机的NIC模型可以用`model=modelname`来设置，使用model=help列举可用设备类型。MAC地址可以使用`mac=macaddr`形式设置。

_-nic none_: 表示没有网络设备配置，它用于覆写默认的配置。

_-netdev user,id=id[,option][,option]..._: 配置用户模式主机网络后端，它不需要管理员权限运行。

**字符设备**

用于设置字符设备，详细内容可以参考英文文档。

**蓝牙选项**

设置蓝牙设备。

**TPM设备选项**

这个暂时不知道做何中用途，暂时不看。

**Linux多引导 引导参数设置**

使用这类选项可以直接使用给定的Linux或多引导内核，而无需安装到磁盘。它对于测试各种内核非常方便。

**调试/专家选项**

_-serial dev_: 重定向虚拟窗口到主机字符设备dev。默认情况下，图形模式时是vc，非图形模式时时stdio。这个选项可以使用多次，最多模拟4个串口。vc虚拟控制台，`vc:800X600`表示宽和高。pty表示Linux上的伪终端，自动分配一个PTY。none表示不分配设备。null表示分配空设备。chardev:id 使用在-chardev中定义的命名字符设备。`/dev/XXX`在linux中使用主机的tty，例如`/dev/ttyS0`表示使用主机的窗口参数。file:filename 表示将输出内容写到filename指定的文件，没有读入字符。pipe:filename使用命名的管道filename。COMn表示在Windows上使用串口n。`udp:[remote_host]:remote_port[@[src_ip]:src_port]`这表示使用一个UDP网络控制台，如果`remote_host`或`src_ip`不指定，默认使用`0.0.0.0`。`tcp:[host]:port[,server][,nowait][,nodelay][,reconnect=seconds]`使用TCP网络控制台，有两种模式操作。

_parallel dev_: 重定向虚拟串口到主机设备dev，类似串口重定向。

_-monitor dev_: 重定向监控器到主机设备dev，类似串口重定向。

_-debugcon dev_: 重定向调试控制台到主机设备dev，类似窗口重定向。调试控制台是一个I/O端口，通常是0xe9；向I/O端口发送数据就会输出到这个设备上。

_-pidfile file_: 保存Qemu进程PID到文件file。如果使用脚本启动Qemu会非常有用。

_-siglestep_: 以单步模式返回到模拟器。

_-S_: 在开始时不要启动CPU，必须在监控器中输入`c`命令才会启动CPU

_-gdb dev_: 在设备dev上等待gdb连接（详细参考gdb_usage）。典型的连接是基于TCP的，但是也可以使用UDP或伪终端或者甚至是stdio也是合理的。stdio允许从gdb中启动Qemu，并且通过管道建立连接。

_-s_: `-gdb tcp::1234`的简写形式，即在TCP端口1234上打开gdbserver。

_-d item[,...]_: 开启指定项目的日志，使用`qemu-system-i386 -d help`显示可以记录的项目。

_-D logfile_: 将日志写入logfile中，而不是标准错误输出。

_-L path_: 设置BIOS，VGA BIOS和键盘映射的目录。列举所有目录可以使用`-L help`。

_-bios file_: 设置BIOS的文件名

_-enable-kvm_: 开启KVM完全虚拟化支持，这个开关只在编译时KVM支持开启时才有效。

**通用对象创建**:

这块属于高级设置，暂时不阅读。

####4.图形前端的快捷键####

在图形模拟中，可以使用特殊的组合键修改模式。默认的键映射如下，但是它可以使用`-alt-grab`等设置选项修改。

`Ctrl-Alt-f`：开启全屏

`Ctrl-Alt-+`：放大屏幕全屏

`Ctrl-Alt--`：收缩屏幕

`Ctrl-Alt-u`：重置回未缩放维度。

`Ctrl-Alt-n`：切换到虚拟控制台n，标准映射为1目标系统显示器，2监视器，3串口。

`Ctrl-Alt`：释放数据和键盘

####5.字符后端多路通道的快捷键####

这个是使用了-nographic参数时的快捷键，暂时不涉及。

####6.Qemu监视器####

Qemu监视器用于向Qemu模拟器发送复杂命令，可以使用它：

* 移除或插入可以插拔媒体映像，例如CD-ROM或软盘
* 冷冻/解冻虚拟机，保存状态到磁盘文件或从磁盘文件中恢复状态
* 没有外部调试的情况下检查VM内部状态

**命令**

在控制台中可以使用如下的命令：

_help/? [cmd]_: 显示所有命令帮助或指定命令cmd的帮助

_commit_: 提交变化到磁盘文件（如果使用了`-snapshot`参数）或后备文件。如果后备文件比快照小，那么后备文件被重置为和快照一样大。

_q/quit_: 退出模拟器

_block\_size_: 客户机运行中重置块映像文件大小。

_block\_stream_: 从后备文件中拷贝数据到快设备。

_eject [-f] device_: 弹出可以出媒体设备，-f表示强制弹出。

_log item[,...]_: 动态地记录特定项目到日志文件

_savevm [tag|id]_: 创建整个虚拟机的快照。如果提供了tag，它使用人可读标识，如果已经有相同的则之前的被替代。更多信息可以参考vm snapshots一节。

_loadvm tag:id_: 设置整个虚拟到tag/id标识的快照

_delvm tag|id_: 删除快照

_singlestep [off]_: 让模拟器进入单步模式，添加off参数则恢复正常。

_stop_: 停止模拟

_c/cont_: 恢复模拟

_system\_wakeup_: 将客户机系统从挂起唤醒。

_gdbserver [port]_: 开启gdbserver会话，默认是port=1234

_x/fmt addr_: 虚拟内存输出，从addr开始。

_xp /fmt addr_: 输出物理内存，从addr开始。fmt是告诉命令如何输出内从的格式，语法是`{count}{format}{size}`，count表示输出几个项目，format是输出格式，x是16进制，d有符号十进制，u表示无符号十进制，o表示八进制，c表示字符，i表示指令。size可以是b表示8比特，h表示16bit，w表示32bit，g表示64比特。h和w在X86上可以指定i格式时各自选择的16或32bit的代码指令大小。

_gpa2hva addr_: 显示在客户机中物理地址addr映射到主机虚拟地址是什么

_gpa2hpa addr_: 客户机物理地址addr映射到主机的物理地址是多少

_p/print /fmt expr_: 打印表达式值，fmt中只有format在使用。

_i /fmt addr [.index]_: 读I/O端口

_o /fmt addr val_: 写I/O端口

_system\_reset_: 重置系统

_system\_powerdown_: 关掉系统电源

_sum addr size_: 计算内存区域的校验和

_device\_add config_: 增加设备

_device\_del id_: 删除设备id

_cup index_: 设置默认CPU

_memsave addr size file_: 保存虚拟内存地址addr处size字节数据到磁盘

_pmemsave addr size file_: 保存物理内存地址addr处size字节数据到磁盘

_boot\_set bootdevicelist_: 定义新的值用于引导设备列表。

_info subcommand_: 显示设备信息

####7.磁盘映像####

Qemu支持很多中磁盘映像格式，包括增长类型的磁盘格式，压缩和加密的磁盘映像

*创建磁盘映像*

可以使用命令`qemu-img create myimage.img mysize`创建一个名字为myimge.img，大小为mysize的磁盘映像。更加详细的创建磁盘的命令参数可以参考英文文档。

####8. 网络模拟####

暂时不看。

####9. 其他设备####

暂时不看。

####10. 直接Linux引导####

暂时不看。

####11. USB模拟####

暂时不看。

####12. VNC安全####

暂时不看。

####13. 用于网络服务的TLS设置####

暂时不看。

####14. GDB使用####

Qemu有与GDB一起工作最原始的支持，在虚拟机运行时可以通过`Ctrl-C`查看它的状态。要使用gdb，启动Qemu时就要使用`-s`参数。它会等待gdb连接：

```
qemu-system-i386 -s -kernel arch/i386/boot/bzImage -hda root-2.4.20.img -append "root=/dev/hda"

Connected to host netword interface: tun0
Waiting gdb connection on port 1234
```

然后在vmlinux可执行文件上启动gdb，在gdb中使用`target remote localhost:1234`连接到qemu，然后可以正常使用gdb了。例如输入命令`c`来启动内核。

如下有一些有用的gdb命令在系统代码调试中使用：

* 使用info reg显示所有的CPU寄存器
* 使用x/10i $eip 显示PC位置的代码
* 使用set architecture i8086用于显示16位代码，使用`x /10i $cs*16+$eip`显示PC位置的代码

高级调试选项：默认的单步执行是带有IRQ和定时器服务例程关闭的单步。设置为这样的形式主要是因为当gdb执行单步时，它期望跳过当前的指令。如果开启了IRQ和定时器服务例程，单步会跳进中断或异常向量中，而不是执行当前指令。这意味着在GDB想要执行之前会遇到相同断点多次。因为很少有环境需要单步进入中断向量。有三个命令可以查询和设置单步行为。

`maintenance packet qqemu.sstepbits`这个命令会显示用于控制单步执行的MASK位：

```
(gdb) maintenance packet qqemu.sstepbits
sending: "qqemu.sstepbits"
received: "ENABLE=1,NOIRQ=2,NOTIMER=4"
```

`maintenance packet qqemu.sstep`这个命令显示用于单步指令执行时的mask值：

```
(gdb) maintenance packet qqemu.sstep
sending: "qqemu.sstep"
received: "0x7"
```

`maintenance packet Qqemu.sstep=HEX_VALUE`这个命令会修改单步执行mask值，如果想要在单步执行中开启IRQ，但是不开启定时器，可以使用如下的命令：

```
(gdb) maintenance packet Qqemu.sstep=0x5
sending: "qemu.sstep=0x5"
received: "OK"
```

####15. 目标OS特定信息####

暂时不看。

By Andy @2018-03-14 15:15:23