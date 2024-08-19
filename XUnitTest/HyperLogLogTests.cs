﻿using System;
using NewLife.Caching;
using NewLife.Log;
using Xunit;

namespace XUnitTest;

[Collection("Basic")]
public class HyperLogLogTests
{
    protected readonly FullRedis _redis;

    public HyperLogLogTests()
    {
        var config = BasicTest.GetConfig();

        _redis = new FullRedis();
        _redis.Init(config);
        _redis.Log = XTrace.Log;

#if DEBUG
        _redis.ClientLog = XTrace.Log;
#endif
    }

    [Fact]
    public void HyperLogLog_Normal()
    {
        var key = "hyper_key";
        var key2 = "hyper_key2";

        // 删除已有
        _redis.Remove(key);
        var hyper = new HyperLogLog(_redis, key);
        _redis.SetExpire(key, TimeSpan.FromSeconds(60));

        // 取出个数
        var count = hyper.Count;
        Assert.Equal(0, count);

        // 添加
        var vs = new[] { "1234", "abcd", "新生命团队", "ABEF" };
        hyper.Add(vs);

        // 对比个数
        var count2 = hyper.Count;
        Assert.Equal(count + vs.Length, count2);


        var hyper2 = new HyperLogLog(_redis, key2);
        hyper2.Add("567", "789");

        var rs = hyper.Merge(key2);
        Assert.True(rs);

        Assert.Equal(vs.Length + hyper2.Count, hyper.Count);
    }
}

public class HyperLogLogTests2 : HyperLogLogTests
{
    public HyperLogLogTests2() : base()
    {
        _redis.Prefix = "NewLife:";
    }
}