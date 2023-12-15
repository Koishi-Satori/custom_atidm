## 自定义泰坦装备消耗战mod
### 感谢lbc的技术支持以及他的反蹲起nut 这真的给了我很大支持

----

由于Linux上的nscn safeio处于可持续化趋势状态, 因此使用了我自己的http io来持久化保存玩家数据

目前NSCN上已有我的一个服在使用该mod, 为```[特莉波卡]自定义泰坦装备消耗战```

## 使用须知
- 请参照我的net io, 部署服务并且**填入你的服务url**, url定义位于custom_ui.nut的const string HTTP_IO_URL
- 启用反蹲起请设置anti_insult.nut的enable_anti_insult为true
- 将libs里的mod同时加入你的服务器mod目录