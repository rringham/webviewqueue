function someLongRunningProcess(pid) {
    Test.setTimeout(function() {
        delay(1000);
        Test.setTimeout(function() {
            Test.test(pid);
        }, 0);
    }, 0);
}

function delay(ms) {
    var cur_d = new Date();
    var cur_ticks = cur_d.getTime();
    var ms_passed = 0;
    while(ms_passed < ms) {
        var d = new Date();
        var ticks = d.getTime();
        ms_passed = ticks - cur_ticks;
    }
}