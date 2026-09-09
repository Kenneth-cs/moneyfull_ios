require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const sharedProjectsRouter = require('./routes/sharedProjects');
const h5AnalyticsRouter = require('./routes/h5Analytics');

const app = express();
const PORT = process.env.PORT || 3001;

// 中间件
app.use(cors());
app.use(express.json());

// 静态资源（Logo 等图片）
app.use('/assets', express.static(path.join(__dirname, '../assets')));

// 路由
app.use('/shared-projects', sharedProjectsRouter);
app.use('/h5', h5AnalyticsRouter);

// 健康检查
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 启动服务
app.listen(PORT, () => {
  console.log(`共享记账服务运行在端口 ${PORT}`);
});

module.exports = app;
