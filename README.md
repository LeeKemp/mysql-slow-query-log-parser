The MySQL slow query log parser converts your slow query logs in to a more usable format. It also adds some interesting information like median and average times.

Here is an example of what the parsed log looks like

```
1 Queries
Taking 4 seconds to complete
Locking for 0 seconds
Average time: 4, Median time 4
Average lock: 0, Median lock 0

DELETE FROM blah WHERE blah1 >= XXX AND blah2<= XXX;
################################################################################

22 Queries
Taking 3 3 seconds to complete
Locking for 0 0 seconds
Average time: 3, Median time 3
Average lock: 0, Median lock 0

select * from table1 WHERE table1.something = table.something and table1.x = XXX;
################################################################################
```

This parser was inspired by the perl mysql_slow_log_parser written by Nathanial Hendler.