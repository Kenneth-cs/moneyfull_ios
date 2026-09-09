const rateLimit = require('express-rate-limit');

// IP级别限流 - 每分钟最多5次join尝试
const joinLimiter = rateLimit({
  windowMs: 60 * 1000, // 1分钟
  max: 5,
  message: { error: '请求过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
});

// device_id级别限流 - 每分钟最多50条写入
const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 50,
  message: { error: '写入过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.body.deviceId || req.ip,
});

module.exports = { joinLimiter, writeLimiter };
