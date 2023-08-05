//
//  ViewController.m
//  NSLockTest
//
//  Created by zzy on 2023/8/5.
//

#import "ViewController.h"
#import <libkern/OSAtomic.h>
#import <os/lock.h>
#import <pthread.h>

@interface ViewController ()
@property (nonatomic, assign) NSInteger ticketSurplusCount;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, assign) OSSpinLock spinlcok;
@property (nonatomic, strong)NSConditionLock *conditionLock;
@property (nonatomic, assign) os_unfair_lock unfairLock;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) NSRecursiveLock *recLock;

@property (nonatomic, strong) NSRecursiveLock *recursiveLock;

@end
os_unfair_lock unfairLock;
pthread_mutex_t _pLock;
int cnt = 0;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    [self startSell];
//    [self conditionLockTest];
    [self recursiveDeadlocks];
//    [self threadBlock];
    
    
    
//    _recursiveLock = [[NSRecursiveLock alloc] init];
//    [self recursiveDeadlocksWithValue:0];
}

- (void) startSell {
    //一共有50张票
    self.ticketSurplusCount = 50;
       
    __weak typeof (self) weakSelf = self;
        
    //一号售票窗口
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
            [weakSelf saleTicketSafeWithConditionLock];
       
    });
        
    //二号售票窗口
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
            [weakSelf saleTicketSafeWithConditionLock];
        
    });
}


//售票的方法
- (void)saleTicketSafe {
    _spinlcok = OS_SPINLOCK_INIT;

    
    
    while (1) {
        OSSpinLockLock(&_spinlcok);
//        os_unfair_lock_lock(&_unfairLock);
        if (self.ticketSurplusCount > 0) {  // 如果还有票，继续售卖
            self.ticketSurplusCount--;
            cnt++;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%ld 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { // 如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完,共售出%d张票", cnt);
            OSSpinLockUnlock(&_spinlcok);
//            os_unfair_lock_unlock(&_unfairLock);
        
            break;
        }
//        os_unfair_lock_unlock(&_unfairLock);
        OSSpinLockUnlock(&_spinlcok);
    }
}
- (void)saleTickWithOsUnfairLock {
//    unfairLock = OS_UNFAIR_LOCK_INIT;
    _lock = [[NSLock alloc] init];
    while(1) {
        // 加锁
//        os_unfair_lock_lock(&unfairLock);
        [_lock lock];
 
        if (self.ticketSurplusCount > 0) {
            self.ticketSurplusCount--;
            cnt++;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%ld 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else {
            [_lock lock];
            NSLog(@"所有火车票均已售完，共售出%d张票", cnt);
            
            // 解锁
//            os_unfair_lock_unlock(&unfairLock);
            [_lock unlock];
            break;
        }
        // 解锁
        [_lock unlock];
//        os_unfair_lock_unlock(&unfairLock);
    }
}

- (void)saleTickWithPthreadLock {

    pthread_mutex_init(&_pLock, NULL);
    while(1) {
        // 加锁

        pthread_mutex_lock(&_pLock);
        if (self.ticketSurplusCount > 0) {
            self.ticketSurplusCount--;
            cnt++;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%ld 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else {
            NSLog(@"所有火车票均已售完，共售出%d张票", cnt);
            
            // 解锁

            pthread_mutex_unlock(&_pLock);
            break;
        }
        // 解锁
        pthread_mutex_unlock(&_pLock);

    }
}
- (void)threadBlock {
    //一共50张票
    self.ticketSurplusCount = 50;
    //初始化NSRecursiveLock递归锁
    _recursiveLock = [[NSRecursiveLock alloc] init];
    
    __weak typeof (self) weakSelf = self;

    for (int i = 0; i < 10; ++i) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf saleTicket];
        });
    }
}

//卖票的函数
- (void)saleTicket {
    //加锁
    [_recursiveLock lock];
    if (self.ticketSurplusCount > 0) {  // 如果还有票，继续售卖
        self.ticketSurplusCount--;
        cnt++;
        NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%ld 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
        [NSThread sleepForTimeInterval:0.2];
        //递归调用卖票函数
        [self saleTicket];
    } else { // 如果已卖完，关闭售票窗口
        NSLog(@"所有火车票均已售完,共售出%d张票", cnt);
    }
    //解锁
    [_recursiveLock unlock];
}
- (void) recursiveDeadlocksWithValue:(int)value {
    [_recursiveLock lock];
    NSLog(@"%d---%@", value, [NSThread currentThread]);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (value > 0) {
            [self recursiveDeadlocksWithValue:value - 1];
        }
        dispatch_group_leave(group);
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [_recursiveLock unlock];
}

//block在复制到堆区的时候被替换了
- (void)recursiveDeadlocks {
    NSRecursiveLock *recursiveLock = [[NSRecursiveLock alloc] init];
    for (int i = 0; i < 10; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            static void (^block)(int);
            
            block = ^(int value) {
                [recursiveLock lock];
                if (value > 0) {
                    NSLog(@"value——%d %@", value, [NSThread currentThread]);
                    block(value - 1);
                }
                [recursiveLock unlock];
                NSLog(@"unlock—— %@", [NSThread currentThread]);
            };
            block(10);
        });
    }
}

//售票的方法
- (void)saleTicketSafeWithConditionLock {
    _condition = [[NSCondition alloc] init];
    while (1) {
        // 加锁
        [_condition lock];
        if (self.ticketSurplusCount > 0) {  // 如果还有票，继续售卖
            self.ticketSurplusCount--;
            cnt++;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%ld 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { // 如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完,共售出%d张票", cnt);
            // 解锁
            [_condition unlock];
            break;
        }
        // 解锁
        [_condition unlock];
    }
}

- (void)conditionLockTest {
    for (int i = 0; i < 5; ++i) {
        //调用测试函数
        [self test];
        //修改Condition参数值为3
        [self.conditionLock lockWhenCondition:0];
        [self.conditionLock unlockWithCondition:3];
    }
    return;
}

//测试函数
- (void)test {
    self.conditionLock = [[NSConditionLock alloc] initWithCondition:3];
    dispatch_queue_t globalQ = dispatch_get_global_queue(0, 0);
    dispatch_async(globalQ, ^{
        [self.conditionLock lockWhenCondition:3];
        NSLog(@"任务1");
        [self.conditionLock unlockWithCondition:2];
    });
    
    dispatch_async(globalQ, ^{
        [self.conditionLock lockWhenCondition:2];
        NSLog(@"任务2");
        [self.conditionLock unlockWithCondition:1];
    });
    
    dispatch_async(globalQ, ^{
        [self.conditionLock lockWhenCondition:1];
        NSLog(@"任务3");
        [self.conditionLock unlockWithCondition:0];
    });
}




@end

