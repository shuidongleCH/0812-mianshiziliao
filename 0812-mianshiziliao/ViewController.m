//
//  ViewController.m
//  OC面试资料汇总
//
//  Created by 陈浩 on 2025/8/10.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

/*
 ### 1. 解释ARC的工作原理
 **文字描述**：
 ARC是编译器自动插入内存管理代码的技术。编译器会在编译时自动在合适的位置添加retain/release/autorelease调用，根据对象的引用计数管理内存。开发者只需关注对象间的引用关系，无需手动管理内存。
 */
// ARC自动插入内存管理代码示例
- (void)example {
    // 编译器自动在作用域结束处添加release
    NSObject *obj = [[NSObject alloc] init];
} // 此处自动插入 [obj release]


/*
 2. 循环引用的常见场景及解决方案
 文字描述：
 当两个对象互相强引用时形成循环引用，导致内存无法释放。常见于Block、Delegate、NSTimer等场景。解决方案是使用__weak打破强引用链，使其中一方持有弱引用。
 */
// Block中的循环引用解决方案
__weak typeof(self) weakSelf = self;
self.completionBlock = ^{
    // 使用弱引用避免强引用循环
    [weakSelf doSomething];
};

/*
 3. 消息转发流程的三个阶段
 文字描述：
 当对象收到无法响应的消息时，Runtime提供三级挽救机会：

 动态方法解析：尝试添加方法实现（+resolveInstanceMethod:）

 备用接收者：将消息转发给其他对象（-forwardingTargetForSelector:）

 完整转发：创建NSInvocation对象进行最后处理（-methodSignatureForSelector:和-forwardInvocation:）
 */
// 动态方法解析示例
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == @selector(missingMethod)) {
        class_addMethod([self class], sel, (IMP)dynamicIMP, "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

void dynamicIMP(id self, SEL _cmd) {
    NSLog(@"动态添加的方法实现");
}

/*
 4. Category的实现原理
 文字描述：
 Category在运行时将方法合并到类的方法列表中。特点：

 可以添加实例方法、类方法、协议

 不能添加成员变量（可通过关联对象实现）

 同名方法优先级：Category > 原类 > 父类

 多个Category的同名方法最终加载顺序不确定
 */
// Category添加关联对象模拟成员变量
@implementation UIViewController (Tracking)

- (void)setPageTag:(NSString *)pageTag {
    objc_setAssociatedObject(self, @selector(pageTag), pageTag, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)pageTag {
    return objc_getAssociatedObject(self, @selector(pageTag));
}
@end

/*
 5. GCD队列类型及使用场景
 文字描述：

 串行队列：任务顺序执行，用于需要同步控制的场景

 并发队列：任务并行执行，适合不依赖顺序的独立任务

 主队列：特殊串行队列，所有UI操作必须在此执行
 关键原则：避免在串行队列中同步提交新任务导致死锁
 */
// 避免死锁的正确写法
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    // 后台执行耗时操作
    NSData *data = [NSData dataWithContentsOfURL:url];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 回到主线程更新UI
        self.imageView.image = [UIImage imageWithData:data];
    });
});

/*
 6. 线程安全的实现方案
 文字描述：
 保证多线程环境下数据一致的常用方法：

 串行队列：所有访问通过同一队列

 栅栏函数：保证写操作独占（dispatch_barrier_async）

 锁机制：NSLock/@synchronized（性能较低）

 原子操作：atomic属性（仅保证setter/getter原子性）
 */
// 使用GCD栅栏函数实现线程安全字典
- (void)setObject:(id)object forKey:(NSString *)key {
    dispatch_barrier_async(self.concurrentQueue, ^{
        [self.mutableDict setObject:object forKey:key];
    });
}

- (id)objectForKey:(NSString *)key {
    __block id result;
    dispatch_sync(self.concurrentQueue, ^{
        result = [self.mutableDict objectForKey:key];
    });
    return result;
}

/*
 7. 委托模式的核心要点
 文字描述：
 委托模式包含三个关键点：

 协议定义：明确委托方需要实现的方法

 弱引用委托：委托属性必须使用weak避免循环引用

 可选方法：使用@optional定义非必须实现的方法

 安全调用：使用respondsToSelector:检查方法实现
 */
// 委托模式实现示例
@protocol DataLoaderDelegate <NSObject>
@optional
- (void)dataDidLoad:(NSArray *)data;
@end

@interface DataLoader : NSObject
@property (weak, nonatomic) id<DataLoaderDelegate> delegate;
@end

@implementation DataLoader
- (void)finishLoading {
    if ([self.delegate respondsToSelector:@selector(dataDidLoad:)]) {
        [self.delegate dataDidLoad:self.data];
    }
}
@end

/*
 8. 观察者模式的实现方案
 文字描述：
 iOS中观察者模式的实现方式：

 KVO：适用于对象属性变化监听，自动触发通知

 通知中心：适用于全局事件广播，一对多通信

 自定义观察者：灵活实现自己的观察逻辑
 关键区别：KVO是对象属性级别，通知是全局事件级别
 */
// KVO注册与响应
// 注册观察者
[obj addObserver:self
      forKeyPath:@"status"
         options:NSKeyValueObservingOptionNew
         context:nil];

// 回调方法
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        NSLog(@"状态变化: %@", change[NSKeyValueChangeNewKey]);
    }
}

/*
 9. 列表滚动性能优化方案
 文字描述：
 解决UITableView/UICollectionView卡顿的关键点：

 Cell重用：正确使用重用机制（registerClass:forCellReuseIdentifier:）

 异步渲染：图片加载使用SDWebImage等异步方案

 离屏渲染优化：避免cornerRadius+masksToBounds组合

 高度预计算：在数据源阶段计算好cell高度

 减少透明视图：透明度<1的视图会增加混合计算
 */
// 离屏渲染优化方案
// 错误做法（产生离屏渲染）：
view.layer.cornerRadius = 10;
view.layer.masksToBounds = YES;

// 正确做法（避免离屏渲染）：
UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:10];
[path addClip];
[view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
view.layer.contents = (__bridge id)image.CGImage;

/*
 10. 内存泄漏检测方法
 文字描述：
 检测内存泄漏的实用方案：

 静态分析：Xcode内置Analyzer（Product > Analyze）

 动态检测：

 Instruments Leak工具

 Debug Memory Graph（可视化对象引用关系）

 第三方工具：MLeaksFinder/FBRetainCycleDetector
 常见泄漏点：Block循环引用、NSTimer未释放、Delegate强引用
 */
// 安全的NSTimer使用（避免循环引用）
@interface Controller ()
@property (strong, nonatomic) NSTimer *timer;
@end

@implementation Controller
- (void)startTimer {
    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf handleTimer];
    }];
}

- (void)dealloc {
    [self.timer invalidate]; // 必须手动停止
}
@end

/*
 ### 1. 消息发送机制原理
 **文字描述**：
 Objective-C方法调用本质是给对象发送消息，通过`objc_msgSend`函数实现。运行时根据对象的isa指针找到类，在方法列表中查找SEL对应的方法实现(IMP)。若未找到，会沿着继承链向上查找，最终触发消息转发机制。这种动态绑定是实现多态的基础。

 ```objective-c
 // 底层消息发送等效代码
 [obj doSomething];
 // 编译后转换为：
 objc_msgSend(obj, @selector(doSomething));
 */

/*
 2. Method Swizzling的注意事项
 文字描述：
 方法交换是运行时替换方法实现的技术，主要用于Hook系统行为。关键注意事项：

 在+load方法中执行保证早期加载

 使用dispatch_once保证线程安全

 交换前检查方法是否存在

 避免交换父类方法影响其他子类
 */
// 安全的方法交换实现
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSel = @selector(viewDidLoad);
        SEL swizzledSel = @selector(swizzled_viewDidLoad);
        
        Method originalMethod = class_getInstanceMethod(class, originalSel);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSel);
        
        // 避免交换未实现的方法
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

/*
 3. AutoreleasePool工作原理
 文字描述：
 自动释放池延迟对象的release时机，将对象加入当前池，在池drain时统一发送release。主线程RunLoop每次循环会自动创建和释放池。在循环创建临时对象或后台线程时，应手动添加@autoreleasepool避免内存峰值。
 */
// 手动使用autoreleasepool优化内存
for (int i = 0; i < 10000; i++) {
    @autoreleasepool {
        // 每次迭代都会释放临时对象
        NSString *temp = [NSString stringWithFormat:@"%d", i];
    }
}

/*
 4. NSTimer的内存泄漏解决方案
 文字描述：
 NSTimer会强引用target对象导致循环引用。解决方案：

 使用block-based API（iOS 10+）

 创建中间代理对象弱引用target

 在dealloc中主动invalidate timer

 使用GCD定时器替代
 */
// 安全的block-based timer
__weak typeof(self) weakSelf = self;
self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
    [weakSelf handleTimerTick]; // 弱引用打破循环
}];

/*
 5. 线程同步方案对比
 文字描述：
 iOS常用线程同步机制对比：

 @synchronized：简单但性能差，基于对象锁

 NSLock：基础锁，需手动lock/unlock

 GCD信号量：适合控制资源访问数量

 OSAtomic：原子操作，性能最佳但仅限简单类型

 pthread_mutex：跨平台C语言锁，可配置属性
 */
// GCD信号量实现资源控制
dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);

dispatch_async(dispatch_get_global_queue(0, 0), ^{
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    // 临界区代码
    dispatch_semaphore_signal(semaphore);
});

/*
 6. 读写锁实现方案
 文字描述：
 读写锁允许多读单写，优化并发性能。实现方案：

 使用pthread_rwlock（C语言API）

 GCD栅栏函数+并发队列

 第三方库如YYThreadSafe
 核心原则：并发读取，互斥写入
 */
// GCD实现读写锁
dispatch_queue_t queue = dispatch_queue_create("com.readwrite.queue", DISPATCH_QUEUE_CONCURRENT);

- (id)objectForKey:(NSString *)key {
    __block id obj;
    dispatch_sync(queue, ^{ // 同步读
        obj = [_dict objectForKey:key];
    });
    return obj;
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    dispatch_barrier_async(queue, ^{ // 异步栅栏写
        [_dict setObject:obj forKey:key];
    });
}

/*
 7. HTTPS证书验证流程
 文字描述：
 HTTPS安全通信三步骤：

 证书验证：客户端验证服务器证书有效性（是否过期/是否信任）

 密钥协商：通过非对称加密交换对称加密密钥

 数据加密：使用对称密钥加密通信内容
 iOS中通过NSURLSessionDelegate的didReceiveChallenge方法处理证书验证
 */
// 证书验证回调
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    
    // 验证服务器证书
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    SecTrustResultType result;
    SecTrustEvaluate(serverTrust, &result);
    
    if (result == kSecTrustResultProceed) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

/*
 8. 大文件断点续传实现
 文字描述：
 实现断点续传的关键技术：

 Range请求头：bytes=start-end指定下载范围

 本地记录：保存已下载字节位置

 文件分片：分块下载合并

 后台下载：使用NSURLSessionBackgroundConfiguration
 */
// 设置Range请求头
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
NSString *range = [NSString stringWithFormat:@"bytes=%lld-", downloadedBytes];
[request setValue:range forHTTPHeaderField:@"Range"];

/*
 9. 图片加载优化策略
 文字描述：
 高性能图片加载方案：

 异步解码：后台线程将图片转为位图

 缓存机制：内存缓存(NSCache)+磁盘缓存

 渐进式加载：先显示低分辨率图片

 按需加载：列表滚动时暂停非可见cell加载

 格式选择：根据场景选择JPG/PNG/WEBP
 */
// 后台线程图片解码
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    CGImageRef decodedImage = [self decodeImage:sourceImage.CGImage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = [UIImage imageWithCGImage:decodedImage];
    });
});

/*
 10. 离屏渲染优化方案
 文字描述：
 避免离屏渲染的实践方法：

 使用cornerRadius时避免同时设置masksToBounds

 阴影使用shadowPath替代自动计算

 使用CoreGraphics绘制圆角替代图层属性

 将需要裁剪的视图封装到父视图

 开启shouldRasterize时合理设置rasterizationScale
 */
// 高效绘制圆角方案
UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
CGContextRef ctx = UIGraphicsGetCurrentContext();
UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:10];
CGContextAddPath(ctx, path.CGPath);
CGContextClip(ctx);
[view.layer renderInContext:ctx];
UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();

/*
 11. 模块化通信方案
 文字描述：
 大型项目模块化通信方式：

 URL路由：通过统一路由中心跳转（如JLRoutes）

 协议解耦：定义protocol，通过服务管理器获取实现

 通知广播：使用NSNotificationCenter跨模块通信

 依赖注入：通过构造函数传递依赖对象
 */
// URL路由跳转示例
[JLRoutes addRoute:@"/user/:id" handler:^BOOL(NSDictionary *parameters) {
    NSString *userId = parameters[@"id"];
    UserVC *vc = [[UserVC alloc] initWithUserId:userId];
    [self.navigationController pushViewController:vc animated:YES];
    return YES;
}];

// 触发路由
[JLRoutes routeURL:@"/user/1234"];

/*
 12. 状态管理方案
 文字描述：
 复杂状态管理常用方案：

 状态机模式：定义有限状态和转换规则

 响应式编程：使用RAC/KVO监听状态变化

 Redux架构：单向数据流+纯函数更新

 状态中心：集中管理关键状态（如登录态）
 */
// 状态机实现示例
typedef NS_ENUM(NSUInteger, DownloadState) {
    DownloadStateIdle,
    DownloadStateInProgress,
    DownloadStatePaused,
    DownloadStateCompleted
};

// 状态转换方法
- (void)transitionToState:(DownloadState)newState {
    switch (_currentState) {
        case DownloadStateIdle:
            if (newState == DownloadStateInProgress) {
                _currentState = newState;
            }
            break;
        // 其他状态转换规则...
    }
}

/*
 13. 敏感数据保护方案
 文字描述：
 保护敏感数据的关键措施：

 Keychain存储：保存认证令牌/密码等

 运行时混淆：防止静态分析获取敏感字符串

 禁止调试：ptrace反调试保护

 代码混淆：加固关键业务逻辑

 网络传输加密：使用AES256加密关键数据
*/
// Keychain存储示例
NSDictionary *query = @{
    (id)kSecClass: (id)kSecClassGenericPassword,
    (id)kSecAttrAccount: @"user_token",
    (id)kSecValueData: [token dataUsingEncoding:NSUTF8StringEncoding]
};
OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);

/*
 14. 反注入保护措施
 文字描述：
 防止代码注入的防御方案：

 检查动态库列表（_dyld_get_image_name）

 校验可执行文件签名

 防止Method Swizzling（检查方法实现地址）

 使用C函数替代易Hook的Objective-C方法
*/
// 检测非法动态库
uint32_t count = _dyld_image_count();
for (uint32_t i = 0; i < count; i++) {
    const char *name = _dyld_get_image_name(i);
    if (strstr(name, "Jailbreak")) {
        exit(0); // 发现越狱库立即退出
    }
}

/*
 15. 符号化崩溃日志
 文字描述：
 符号化崩溃日志三步骤：

 获取匹配的dSYM文件

 使用atos命令定位堆栈地址

 通过Xcode Organizer自动符号化
 关键点：保证UUID匹配（dwarfdump --uuid验证）
*/
# 命令行符号化示例
atos -o MyApp.dSYM/Contents/Resources/DWARF/MyApp -arch arm64 -l 0x100000000 0x00000001000abcde

/*
 16. 内存问题检测方案
 文字描述：
 检测内存问题的工具链：

 静态分析：Xcode Analyze（Shift+Cmd+B）

 动态检测：

 Instruments Allocations跟踪内存分配

 Zombies检测野指针

 Leaks检测内存泄漏

 Debug Memory Graph：可视化对象引用关系
*/
// 启用Zombie Objects
// 在环境变量添加：NSZombieEnabled=YES

/*
 17. RunLoop工作机制
 文字描述：
 RunLoop事件处理循环：

 接收输入事件（Source0/Source1）

 执行定时器（Timers）

 处理待执行任务（Observers）

 进入休眠等待唤醒
 主线程RunLoop默认包含多个Mode，滚动时切换到TrackingMode提升流畅性
*/
// 观察RunLoop状态变化
CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
    switch (activity) {
        case kCFRunLoopEntry: NSLog(@"进入RunLoop"); break;
        case kCFRunLoopBeforeTimers: NSLog(@"即将处理Timer"); break;
        // 其他状态...
    }
});
CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);

/*
 18. Block内存管理
 文字描述：
 Block内存管理关键点：

 捕获变量：基本类型值捕获，对象类型强引用

 内存位置：

 全局Block（未捕获变量）

 栈Block（MRC下存在）

 堆Block（ARC自动拷贝）

 循环引用：通过__weak打破强引用环
*/
// Block内存类型验证
int num = 10;
void (^stackBlock)(void) = ^{ NSLog(@"%d", num); };
NSLog(@"%@", stackBlock); // 输出：<__NSStackBlock__: 0x7...>

void (^heapBlock)(void) = [stackBlock copy];
NSLog(@"%@", heapBlock); // 输出：<__NSMallocBlock__: 0x6...>

/*
 19. 工厂模式实践
 文字描述：
 工厂模式封装对象创建过程：

 简单工厂：通过类型参数创建不同产品

 工厂方法：子类决定实例化哪个类

 抽象工厂：创建产品族
 iOS中类簇（如NSNumber）是工厂模式的典型实现
*/
// 简单工厂实现
+ (UIButton *)buttonWithType:(ButtonType)type {
    switch (type) {
        case Primary: return [PrimaryButton new];
        case Secondary: return [SecondaryButton new];
        case Danger: return [DangerButton new];
    }
}

// 使用
UIButton *btn = [ButtonFactory buttonWithType:ButtonTypePrimary];

/*
 20. 响应链传递机制
 文字描述：
 事件响应链传递流程：

 从初始视图（hit-test view）开始

 沿视图层级向上传递（nextResponder）

 到达UIWindow -> UIApplication

 最终由UIApplicationDelegate处理
 可通过重写pointInside:withEvent:和hitTest:withEvent:自定义响应逻辑
*/
// 自定义hitTest实现
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.isUserInteractionEnabled || self.isHidden || self.alpha <= 0.01) {
        return nil;
    }
    
    // 扩大点击区域
    CGRect touchRect = CGRectInset(self.bounds, -10, -10);
    if (CGRectContainsPoint(touchRect, point)) {
        for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
            CGPoint convertedPoint = [subview convertPoint:point fromView:self];
            UIView *hitView = [subview hitTest:convertedPoint withEvent:event];
            if (hitView) return hitView;
        }
        return self;
    }
    return nil;
}

/*
 面试表达黄金法则：

 STAR原则：描述项目经验时按Situation-Task-Action-Result结构

 3C表达法：Clear（清晰）Concise（简洁）Concrete（具体）

 技术对比：当被问及方案选型时，对比优缺点再下结论

 承认未知：对不了解的技术诚实回答，但补充学习意向

 代码阐述：解释代码时先说明场景，再描述关键实现，最后总结收益
*/


/*
 ### 1. 类与元类的关系
 **文字描述**：
 每个类都有一个隐藏的元类（Meta Class），存储类的类方法。元类的isa指向根元类，根元类的isa指向自身，形成闭环。这种结构保证了类方法的继承链与实例方法平行。
*/
// 验证元类
Class class = [NSObject class];
Class metaClass = object_getClass(class);
NSLog(@"NSObject元类: %@", NSStringFromClass(metaClass));

/*
 2. IMP缓存机制
 文字描述：
 Runtime使用方法缓存（cache_t）加速消息发送。首次查找方法后会缓存IMP，后续调用直接跳转。缓存策略采用哈希表，容量动态扩展。当方法列表变动（如Category加载）时缓存会清空。
*/
// 直接调用IMP提升性能
void (*setter)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[target methodForSelector:@selector(setEnabled:)];
setter(target, @selector(setEnabled:), YES);

/*
 3. __autoreleasing使用场景
 文字描述：
 用于按引用传递对象给需要释放所有权的参数（NSError **）。ARC会自动插入retain/autorelease调用，对象会被加入最近的自动释放池，延迟释放时机。
*/
// 错误处理中的典型用法
NSError *__autoreleasing error;
if (![data writeToFile:path options:0 error:&error]) {
    NSLog(@"写入失败: %@", error);
}

/*
 4. dealloc实现要点
 文字描述：
 dealloc中需完成：

 移除KVO观察和通知监听

 停止NSTimer和网络请求

 释放CoreFoundation对象

 清除非ARC内存
 注意：避免调用属性访问器，应直接操作实例变量。
*/
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate]; // 非ARC需retain后释放
    CFRelease(_cfObject);
}

/*
 5. 线程保活技术
 文字描述：
 通过RunLoop实现线程常驻：

 添加Port/Mach Port作为事件源

 调用run方法启动RunLoop

 使用performSelector:onThread:提交任务

 结束时removePort并stop RunLoop
*/
// 创建常驻线程
_thread = [[NSThread alloc] initWithBlock:^{
    @autoreleasepool {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}];
[_thread start];

// 提交任务
[self performSelector:@selector(task) onThread:_thread withObject:nil waitUntilDone:NO];

/*
 6. 读写锁替代方案
 文字描述：
 除pthread_rwlock外，还可使用：

 GCD栅栏实现并发安全读写

 OSAtomic系列原子操作

 NSLock锁（性能较低）

 自旋锁（iOS 10+已弃用OSSpinLock）
*/
// GCD栅栏实现读写锁
dispatch_queue_t queue = dispatch_queue_create("com.readwrite.queue", DISPATCH_QUEUE_CONCURRENT);

- (id)objectForKey:(NSString *)key {
    __block id value;
    dispatch_sync(queue, ^{ value = _dictionary[key]; });
    return value;
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    dispatch_barrier_async(queue, ^{ _dictionary[key] = obj; });
}

/*
 7. HTTP/2特性利用
 文字描述：
 HTTP/2在iOS的优势：

 多路复用（多个请求单TCP连接）

 头部压缩（HPACK算法）

 服务器推送（Server Push）

 请求优先级
 NSURLSession自动支持ALPN协商，需服务器启用HTTPS。
*/
// 检查HTTP版本
NSURLSessionTask *task = [session dataTaskWithURL:url];
[task resume];
NSLog(@"HTTP版本: %@", task.response.URL.host);

/*
 8. 后台下载配置
 文字描述：
 实现后台下载步骤：

 创建后台会话配置（backgroundSessionConfigurationWithIdentifier:）

 实现URLSession:downloadTask:didFinishDownloadingToURL:

 处理应用挂起时的完成事件（handleEventsForBackgroundURLSession:）

 系统独立进程处理下载，应用唤醒后回调
*/
// 后台会话配置
NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.app.bgdownload"];
NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

/*
 9. 光栅化优化原理
 文字描述：
 shouldRasterize=YES时，图层会被渲染为位图缓存复用，适用于：

 静态或低频变化内容

 含子视图的复杂图层

 动画中的非变化元素
 需配合rasterizationScale适配Retina屏，缓存超时由cacheTimeout控制。
*/
// 光栅化设置
view.layer.shouldRasterize = YES;
view.layer.rasterizationScale = [UIScreen mainScreen].scale;

/*
 10. 离屏渲染检测
 文字描述：
 检测离屏渲染方法：

 Xcode Debug -> View Debugging -> Rendering -> Color Offscreen-Rendered

 Instruments Core Animation -> Debug Options

 代码检测：layer.shouldRasterize && layer.rasterizationScale
 常见触发场景：圆角+裁切、阴影、遮罩。
*/
// 调试期检测代码
#if DEBUG
#define OSDetect() { \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        [self addObserver:self forKeyPath:@"layer.shouldRasterize" options:NSKeyValueObservingOptionNew context:nil]; \
    }); \
}
#else
#define OSDetect()
#endif

/*
 11. 协调器模式
 文字描述：
 协调器（Coordinator）负责导航逻辑：

 解耦视图控制器跳转关系

 集中管理导航栈

 支持跨模块路由

 实现父子协调器层级
 优势：解决Massive VC问题，提升导航可测试性。
*/
// 协调器协议
@protocol Coordinator <NSObject>
- (void)start;
- (void)handleRoute:(NSString *)route;
@end

// 应用根协调器
@interface AppCoordinator : NSObject <Coordinator>
@property (strong, nonatomic) UINavigationController *navigationController;
@end

/*
 12. 单向数据流实践
 文字描述：
 单向数据流核心原则：

 状态（State）唯一数据源

 视图（View）根据状态渲染

 行为（Action）触发状态变更

 状态更新后自动刷新视图
 iOS实现：ReactiveObjC/Combine绑定State和View。
*/
// 状态管理示例
typedef NS_ENUM(NSUInteger, ViewState) {
    ViewStateLoading,
    ViewStateContent,
    ViewStateError
};

// 状态变更触发UI更新
- (void)setCurrentState:(ViewState)currentState {
    _currentState = currentState;
    [self updateUI];
}

/*
 13. 敏感逻辑保护
 文字描述：
 保护关键业务逻辑：

 方法混淆（attribute((always_inline))）

 反调试（ptrace(PT_DENY_ATTACH)）

 代码混淆（LLVM混淆器）

 校验方法地址防Hook

 使用C函数替代ObjC方法
*/
// 反调试防护
#import <dlfcn.h>
#import <sys/types.h>

static void disable_gdb() {
    void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    int (*ptrace_p)(int, pid_t, caddr_t, int);
    ptrace_p = dlsym(handle, "ptrace");
    if(ptrace_p) ptrace_p(31, 0, 0, 0); // PT_DENY_ATTACH
}

/*
 14. 越狱环境检测
 文字描述：
 检测越狱设备方法：

 检查越狱常见路径（/Applications/Cydia.app）

 尝试写入/private目录

 检测动态库注入（dyld_get_image_count）

 检查符号链接（/etc/fstab）

 使用syscall检测越狱行为
*/
// 越狱文件检测
+ (BOOL)isJailbroken {
    NSArray *paths = @[@"/Applications/Cydia.app",
                      @"/usr/sbin/sshd"];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return YES;
        }
    }
    return NO;
}

/*
 15. 动态调试技术
 文字描述：
 高级调试手段：

 LLDB脚本化调试（breakpoint command add）

 符号断点（-[NSView setNeedsDisplay:]）

 内存断点（watchpoint set variable）

 反汇编调试（disassemble -a）

 运行时类转储（objc/dump-classes）
*/
// LLDB自动化调试示例
(lldb) breakpoint set -n "-[UIViewController viewDidLoad]"
(lldb) breakpoint command add
> po $arg1
> continue
> DONE

/*
 16. 崩溃日志符号化
 文字描述：
 符号化步骤：

 获取匹配的dSYM文件

 使用atos命令定位地址

 Xcode Organizer自动解析

 第三方服务（Bugly/Firebase）
 关键点：UUID匹配（dwarfdump --uuid验证）
*/
# 命令行符号化
atos -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -arch arm64 -l 0x100000000 0x00000001000abcde

/*
 # 命令行符号化
 atos -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -arch arm64 -l 0x100000000 0x00000001000abcde
*/
// 性能敏感循环优化
for (int i = 0; i < 10000; i++) {
    // 原始调用：[obj process] x 10000次
    IMP imp = [obj methodForSelector:@selector(process)];
    void (*func)(id, SEL) = (void *)imp;
    func(obj, @selector(process)); // 无查找开销
}

/*
 18. Block内存布局
 文字描述：
 Block内存结构：

 isa指针（全局/栈/堆Block）

 标志位（引用类型、有无copy/dispose）

 函数指针

 捕获变量（基本类型值拷贝，对象指针）

 特殊辅助函数（copy/dispose）
*/
// Block结构伪代码
struct Block_layout {
    void *isa;
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor *descriptor;
    // 捕获变量...
};

/*
 19. JSPatch热修复
 文字描述：
 热修复原理：

 JavaScriptCore执行JS脚本

 Runtime动态替换方法

 消息转发机制调用JS函数

 支持方法增删/协议实现
 风险：Apple审核条款限制使用。
*/
// JS修复示例
[JPEngine startEngine];
[JPEngine evaluateScript:@"\
  defineClass('UIViewController', {\
    viewDidLoad: function() {\
      super.viewDidLoad();\
      console.log('Patched!');\
    }\
  })\
"];

/*
 20. Flutter混合栈管理
 文字描述：
 混合开发导航管理：

 FlutterViewController作为容器

 平台通道（Platform Channel）通信

 统一路由协议（RouteInformation）

 状态同步（WidgetsBindingObserver）
 关键点：原生导航栈与Flutter路由栈同步。
*/
// Flutter页面跳转原生
FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"navigation" binaryMessenger:controller];
[channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([call.method isEqualToString:@"openNative"]) {
        [self.navigationController pushViewController:[NativeVC new] animated:YES];
        result(@YES);
    }
}];
/*
 面试表达专家建议：

 问题分级：区分核心问题（★）与进阶问题（★★）的回答深度

 时间控制：普通问题≤2分钟，系统设计类≤5分钟

 错误处理：被指出错误时先确认，再讨论差异点（"您提到的X方案，在Y场景下确实是更好的选择"）

 方案演进：描述技术演进过程（如"早期用MRC，现在ARC已成为标准"）

 业务结合：始终关联实际业务场景（如"在电商App的购物车模块应用了XX技术"）
 */

/*

*/

/*

*/

/*

*/

/*

*/

/*

*/

/*

*/

/*

*/

- (void)viewDidLoad {
    [super viewDidLoad];
}

@end
