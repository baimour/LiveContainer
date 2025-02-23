@import Foundation;

 __attribute__((constructor))
static void TestJITLessConstructor() {
    NSLog(@"无JIT测试成功");
    setenv("LC_JITLESS_TEST_LOADED", "1", 1);
}
