attestation daemon (kernel thread)
// SPDX-License-Identifier: MIT
#include <linux/kthread.h>
#include <linux/delay.h>
#include <net/sock.h>
#include "id_engine.h"

struct ie_dev *ie_global;

static int attd_fn(void *arg)
{
    u8 nonce[32], quote[512];
    size_t qlen = sizeof(quote);
    u32 tick = 0;
    int ret;

    while (!kthread_should_stop()) {
        msleep(30000);
        tick++;

        get_random_bytes(nonce, sizeof(nonce));
        qlen = sizeof(quote);
        ret = ie_quote(ie_global, nonce, quote, &qlen);
        if (ret) { pr_err("attd: quote failed %d\n", ret); continue; }

        /* POST /attest {tick, quote} to verifier */
        ret = attd_post(quote, qlen);
        if (ret) {
            pr_warn("attd: verifier unreachable, tick %u\n", tick);
            continue;
        }
        pr_info("attd: quote %u accepted (%zu bytes)\n", tick, qlen);
    }
    return 0;
}

static struct task_struct *attd_task;
static int __init attd_init(void) { attd_task = kthread_run(attd_fn, NULL, "attd"); return 0; }
static void __exit attd_exit(void) { kthread_stop(attd_task); }
module_init(attd_init);
module_exit(attd_exit);
MODULE_LICENSE("GPL");
