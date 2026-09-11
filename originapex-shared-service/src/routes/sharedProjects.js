const express = require('express');
const path = require('path');
const router = express.Router();
const db = require('../db');
const { generateUniqueCode } = require('../utils/inviteCode');
const { joinLimiter, writeLimiter } = require('../utils/rateLimit');

// 静态资源（Logo 等图片）—— 放在 /shared-api/assets/ 路径下
router.use('/assets', express.static(path.join(__dirname, '../../assets')));

// 3.1 创建共享项目
router.post('/', async (req, res) => {
  try {
    const { id, name, createdByDeviceId, creatorName } = req.body;

    if (!id || !name || !createdByDeviceId || !creatorName) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    const inviteCode = await generateUniqueCode(db);

    await db.execute(
      'INSERT INTO mf_shared_projects (id, invite_code, name, created_by_device_id) VALUES (?, ?, ?, ?)',
      [id, inviteCode, name, createdByDeviceId]
    );

    // 创建者自动成为成员
    await db.execute(
      'INSERT INTO mf_shared_project_members (project_id, device_id, participant_name) VALUES (?, ?, ?)',
      [id, createdByDeviceId, creatorName]
    );

    res.status(201).json({
      projectId: id,
      inviteCode,
      name
    });
  } catch (error) {
    console.error('创建项目失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.2 通过邀请码加入项目
router.post('/join', joinLimiter, async (req, res) => {
  try {
    const { inviteCode, deviceId, participantName } = req.body;

    if (!inviteCode || !deviceId || !participantName) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    // 查找项目
    const [projects] = await db.execute(
      'SELECT id, name FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '邀请码不存在或已失效' });
    }

    const project = projects[0];

    // 检查是否已经是成员
    const [existing] = await db.execute(
      'SELECT id FROM mf_shared_project_members WHERE project_id = ? AND device_id = ?',
      [project.id, deviceId]
    );

    if (existing.length === 0) {
      // 添加为新成员
      await db.execute(
        'INSERT INTO mf_shared_project_members (project_id, device_id, participant_name) VALUES (?, ?, ?)',
        [project.id, deviceId, participantName]
      );
    }

    // 获取所有成员
    const [members] = await db.execute(
      'SELECT participant_name, joined_at FROM mf_shared_project_members WHERE project_id = ?',
      [project.id]
    );

    res.json({
      projectId: project.id,
      name: project.name,
      members: members.map(m => ({
        participantName: m.participant_name,
        joinedAt: m.joined_at
      }))
    });
  } catch (error) {
    console.error('加入项目失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.3 拉取流水（增量同步）
router.get('/:inviteCode/transactions', async (req, res) => {
  try {
    const { inviteCode } = req.params;
    const { since, deviceId } = req.query;

    // 验证项目存在
    const [projects] = await db.execute(
      'SELECT id FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    const projectId = projects[0].id;

    let query = 'SELECT id, device_id, participant_name, payer_name, participants, split_method, amount, category, note, transaction_at, is_deleted, server_updated_at FROM mf_shared_transactions WHERE project_id = ?';
    let params = [projectId];

    if (since) {
      query += ' AND server_updated_at > ?';
      params.push(since);
    }

    query += ' ORDER BY server_updated_at ASC';

    const [transactions] = await db.execute(query, params);

    res.json({
      transactions: transactions.map(t => ({
        id: t.id,
        deviceId: t.device_id,
        participantName: t.participant_name,
        payerName: t.payer_name,
        participants: t.participants ? (typeof t.participants === 'string' ? JSON.parse(t.participants) : t.participants) : null,
        splitMethod: t.split_method,
        amount: parseFloat(t.amount),
        category: t.category,
        note: t.note,
        transactionAt: t.transaction_at,
        isDeleted: t.is_deleted === 1,
        serverUpdatedAt: t.server_updated_at
      })),
      serverTime: new Date().toISOString()
    });
  } catch (error) {
    console.error('拉取流水失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.4 写入流水（支持批量）
router.post('/:inviteCode/transactions', writeLimiter, async (req, res) => {
  try {
    const { inviteCode } = req.params;
    const { deviceId, transactions } = req.body;

    if (!deviceId || !transactions || !Array.isArray(transactions)) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    // 验证项目存在
    const [projects] = await db.execute(
      'SELECT id FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    const projectId = projects[0].id;

    // 获取成员昵称
    const [members] = await db.execute(
      'SELECT participant_name FROM mf_shared_project_members WHERE project_id = ? AND device_id = ?',
      [projectId, deviceId]
    );

    const participantName = members.length > 0 ? members[0].participant_name : '未知';

    const savedIds = [];

    // 日期格式转换为MySQL支持的格式
    const formatDate = (dateStr) => {
      if (!dateStr) return null;
      const d = new Date(dateStr);
      return d.toISOString().slice(0, 19).replace('T', ' ');
    };

    // 批量写入
    for (const t of transactions) {
      const payerName = t.payerName || participantName;
      const participants = t.participants ? JSON.stringify(t.participants) : null;
      const splitMethod = t.splitMethod || 'equal';
      const transactionAt = formatDate(t.transactionAt);

      await db.execute(
        `INSERT INTO mf_shared_transactions (id, project_id, device_id, participant_name, payer_name, participants, split_method, amount, category, note, transaction_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           amount = VALUES(amount),
           category = VALUES(category),
           note = VALUES(note),
           transaction_at = VALUES(transaction_at),
           payer_name = VALUES(payer_name),
           participants = VALUES(participants),
           split_method = VALUES(split_method)`,
        [t.id, projectId, deviceId, participantName, payerName, participants, splitMethod, t.amount, t.category, t.note, transactionAt]
      );
      savedIds.push(t.id);
    }

    res.json({
      saved: savedIds,
      serverTime: new Date().toISOString()
    });
  } catch (error) {
    console.error('写入流水失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.5 删除流水（逻辑删除）
router.delete('/:inviteCode/transactions/:transactionId', async (req, res) => {
  try {
    const { inviteCode, transactionId } = req.params;
    const { deviceId } = req.body;

    if (!deviceId) {
      return res.status(400).json({ error: '缺少deviceId' });
    }

    // 验证项目存在
    const [projects] = await db.execute(
      'SELECT id FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    // 验证是否是自己记的
    const [transactions] = await db.execute(
      'SELECT device_id FROM mf_shared_transactions WHERE id = ? AND project_id = ?',
      [transactionId, projects[0].id]
    );

    if (transactions.length === 0) {
      return res.status(404).json({ error: '流水不存在' });
    }

    if (transactions[0].device_id !== deviceId) {
      return res.status(403).json({ error: '只能删除自己记录的流水' });
    }

    // 逻辑删除
    await db.execute(
      'UPDATE mf_shared_transactions SET is_deleted = 1 WHERE id = ?',
      [transactionId]
    );

    res.json({ ok: true });
  } catch (error) {
    console.error('删除流水失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.6 退出/解散共享项目
router.delete('/:inviteCode/members/:deviceId', async (req, res) => {
  try {
    const { inviteCode, deviceId } = req.params;

    // 查找项目
    const [projects] = await db.execute(
      'SELECT id, created_by_device_id FROM mf_shared_projects WHERE invite_code = ?',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    const project = projects[0];

    if (project.created_by_device_id === deviceId) {
      // 创建者退出 = 解散项目
      await db.execute(
        'UPDATE mf_shared_projects SET is_deleted = 1 WHERE id = ?',
        [project.id]
      );
    } else {
      // 普通成员退出
      await db.execute(
        'DELETE FROM mf_shared_project_members WHERE project_id = ? AND device_id = ?',
        [project.id, deviceId]
      );
    }

    res.json({ ok: true });
  } catch (error) {
    console.error('退出项目失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 3.7 修改项目名称（仅创建者可改）
router.patch('/:inviteCode/name', async (req, res) => {
  try {
    const { inviteCode } = req.params;
    const { deviceId, name } = req.body;

    if (!deviceId || !name || !name.trim()) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    const [projects] = await db.execute(
      'SELECT id, created_by_device_id FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    if (projects[0].created_by_device_id !== deviceId) {
      return res.status(403).json({ error: '只有创建者才能修改项目名称' });
    }

    await db.execute(
      'UPDATE mf_shared_projects SET name = ? WHERE id = ?',
      [name.trim(), projects[0].id]
    );

    res.json({ ok: true, name: name.trim() });
  } catch (error) {
    console.error('修改项目名称失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取项目详情（加入前预览）
router.get('/:inviteCode/info', async (req, res) => {
  try {
    const { inviteCode } = req.params;

    const [projects] = await db.execute(
      'SELECT id, name, created_at FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '邀请码不存在或已失效' });
    }

    const project = projects[0];

    const [members] = await db.execute(
      'SELECT participant_name, joined_at FROM mf_shared_project_members WHERE project_id = ?',
      [project.id]
    );

    res.json({
      projectId: project.id,
      name: project.name,
      memberCount: members.length,
      members: members.map(m => ({
        participantName: m.participant_name,
        joinedAt: m.joined_at
      })),
      createdAt: project.created_at
    });
  } catch (error) {
    console.error('获取项目详情失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取成员统计（服务端聚合）
router.get('/:inviteCode/stats', async (req, res) => {
  try {
    const { inviteCode } = req.params;

    const [projects] = await db.execute(
      'SELECT id FROM mf_shared_projects WHERE invite_code = ? AND is_deleted = 0',
      [inviteCode]
    );

    if (projects.length === 0) {
      return res.status(404).json({ error: '项目不存在' });
    }

    const projectId = projects[0].id;

    // 获取所有成员
    const [members] = await db.execute(
      'SELECT participant_name, device_id FROM mf_shared_project_members WHERE project_id = ?',
      [projectId]
    );

    // 计算每个成员的统计
    const memberStats = [];

    for (const member of members) {
      // totalPaid: payer_name = 成员 的金额之和（旧数据降级用 participant_name）
      const [paidRows] = await db.execute(
        `SELECT COALESCE(SUM(ABS(amount)), 0) as total_paid
         FROM mf_shared_transactions
         WHERE project_id = ? AND is_deleted = 0
           AND (payer_name = ? OR (payer_name IS NULL AND participant_name = ?))`,
        [projectId, member.participant_name, member.participant_name]
      );

      // totalConsumed: participants JSON 包含该成员的流水，按人数平摊后之和
      const [consumedRows] = await db.execute(
        `SELECT COALESCE(SUM(ABS(amount) / JSON_LENGTH(participants)), 0) as total_consumed
         FROM mf_shared_transactions
         WHERE project_id = ? AND is_deleted = 0
           AND participants IS NOT NULL
           AND JSON_CONTAINS(participants, ?)`,
        [projectId, `"${member.participant_name}"`]
      );

      // 旧数据（participants 为 NULL）视为全员参与，按成员总数平摊
      const [legacyRows] = await db.execute(
        `SELECT COALESCE(SUM(ABS(amount) / ?), 0) as legacy_consumed
         FROM mf_shared_transactions
         WHERE project_id = ? AND is_deleted = 0
           AND participants IS NULL`,
        [members.length, projectId]
      );

      const totalPaid = parseFloat(paidRows[0].total_paid);
      const totalConsumed = parseFloat(consumedRows[0].total_consumed) + parseFloat(legacyRows[0].legacy_consumed);

      memberStats.push({
        participantName: member.participant_name,
        deviceId: member.device_id,
        totalPaid,
        totalConsumed
      });
    }

    // 总支出
    const [totalRows] = await db.execute(
      'SELECT COALESCE(SUM(ABS(amount)), 0) as total_amount FROM mf_shared_transactions WHERE project_id = ? AND is_deleted = 0',
      [projectId]
    );

    res.json({
      totalAmount: parseFloat(totalRows[0].total_amount),
      memberStats
    });
  } catch (error) {
    console.error('获取统计失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 获取用户加入的项目列表
router.get('/my-projects', async (req, res) => {
  try {
    const { deviceId } = req.query;

    if (!deviceId) {
      return res.status(400).json({ error: '缺少deviceId' });
    }

    const [projects] = await db.execute(
      `SELECT p.id, p.invite_code, p.name, m.participant_name, p.created_at
       FROM mf_shared_projects p
       JOIN mf_shared_project_members m ON p.id = m.project_id
       WHERE m.device_id = ? AND p.is_deleted = 0`,
      [deviceId]
    );

    res.json({
      projects: projects.map(p => ({
        projectId: p.id,
        inviteCode: p.invite_code,
        name: p.name,
        participantName: p.participant_name,
        createdAt: p.created_at
      }))
    });
  } catch (error) {
    console.error('获取项目列表失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// H5 账单汇总报告页（分享用，需知道邀请码才能访问）
router.get('/:inviteCode/report', async (req, res) => {
  try {
    const { inviteCode } = req.params;

    // 查项目基本信息
    const [projects] = await db.execute(
      `SELECT p.id, p.name, p.created_by_device_id, p.created_at
       FROM mf_shared_projects p
       WHERE p.invite_code = ? AND p.is_deleted = 0`,
      [inviteCode]
    );
    if (projects.length === 0) {
      return res.status(404).send('<html><body style="font-family:sans-serif;text-align:center;padding:60px"><h2>账本不存在或已失效</h2></body></html>');
    }
    const proj = projects[0];

    // 查成员统计
    const [stats] = await db.execute(
      `SELECT participant_name,
              SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS total_spent,
              COUNT(CASE WHEN amount < 0 THEN 1 END) AS tx_count
       FROM mf_shared_transactions
       WHERE project_id = ? AND is_deleted = 0
       GROUP BY participant_name
       ORDER BY total_spent DESC`,
      [proj.id]
    );

    // 查最近 8 条流水
    const [recent] = await db.execute(
      `SELECT participant_name, amount, category, note, transaction_at
       FROM mf_shared_transactions
       WHERE project_id = ? AND is_deleted = 0
       ORDER BY transaction_at DESC LIMIT 8`,
      [proj.id]
    );

    const totalSpent = stats.reduce((s, m) => s + parseFloat(m.total_spent || 0), 0);
    const memberCount = stats.length;

    const memberRows = stats.map(m => {
      const pct = totalSpent > 0 ? ((parseFloat(m.total_spent) / totalSpent) * 100).toFixed(0) : 0;
      const barW = totalSpent > 0 ? ((parseFloat(m.total_spent) / totalSpent) * 100).toFixed(1) : 0;
      return `
        <div class="member-row">
          <div class="member-avatar">${(m.participant_name || '?').charAt(0)}</div>
          <div class="member-info">
            <div class="member-name">${m.participant_name || '未知'}</div>
            <div class="bar-wrap"><div class="bar" style="width:${barW}%"></div></div>
          </div>
          <div class="member-stat">
            <div class="member-amount">¥${parseFloat(m.total_spent).toFixed(2)}</div>
            <div class="member-pct">${pct}%</div>
          </div>
        </div>`;
    }).join('');

    const categoryMap = {};
    recent.forEach(t => {
      if (t.amount < 0) {
        const c = t.category || '其他';
        categoryMap[c] = (categoryMap[c] || 0) + Math.abs(parseFloat(t.amount));
      }
    });

    const recentRows = recent.map(t => {
      const sign = parseFloat(t.amount) < 0 ? '-' : '+';
      const color = parseFloat(t.amount) < 0 ? '#E05C5C' : '#2C6957';
      const d = new Date(t.transaction_at);
      const dateStr = `${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
      return `
        <div class="tx-row">
          <div class="tx-left">
            <div class="tx-cat">${t.category || '其他'}</div>
            <div class="tx-meta">${t.participant_name || ''} · ${dateStr}</div>
          </div>
          <div class="tx-amount" style="color:${color}">${sign}¥${Math.abs(parseFloat(t.amount)).toFixed(2)}</div>
        </div>`;
    }).join('');

    const deepLink = 'moneyfull://open';
    const createdDate = new Date(proj.created_at).toLocaleDateString('zh-CN', { year:'numeric', month:'long', day:'numeric' });

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>「${proj.name}」共享账单</title>
  <meta property="og:title" content="「${proj.name}」共享账单">
  <meta property="og:description" content="${memberCount} 位成员 · 共支出 ¥${totalSpent.toFixed(2)}">
  <meta property="og:image" content="https://originapex.cn/shared-api/assets/logo.png">
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;background:#f2f4f6;min-height:100vh;padding:20px 16px 40px}
    .header{background:linear-gradient(135deg,#5BAF8A,#2C6957);border-radius:20px;padding:24px 20px;color:#fff;margin-bottom:12px}
    .header-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}
    .proj-name{font-size:22px;font-weight:800}
    .proj-meta{font-size:12px;opacity:.75}
    .badge{background:rgba(255,255,255,.2);padding:4px 12px;border-radius:20px;font-size:12px;font-weight:700}
    .stats-row{display:flex;gap:0}
    .stat{flex:1;text-align:center}
    .stat-val{font-size:22px;font-weight:900}
    .stat-label{font-size:11px;opacity:.7;margin-top:2px}
    .divider-v{width:1px;background:rgba(255,255,255,.3);margin:4px 0}
    .card{background:#fff;border-radius:16px;padding:16px 20px;margin-bottom:12px}
    .card-title{font-size:14px;font-weight:700;color:#1a1a1a;margin-bottom:14px}
    .member-row{display:flex;align-items:center;gap:12px;margin-bottom:12px}
    .member-row:last-child{margin-bottom:0}
    .member-avatar{width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,#5BAF8A,#2C6957);color:#fff;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800;flex-shrink:0}
    .member-info{flex:1}
    .member-name{font-size:14px;font-weight:600;color:#1a1a1a;margin-bottom:5px}
    .bar-wrap{height:5px;background:#f0f0f0;border-radius:3px;overflow:hidden}
    .bar{height:100%;background:linear-gradient(90deg,#5BAF8A,#2C6957);border-radius:3px;transition:width .3s}
    .member-stat{text-align:right}
    .member-amount{font-size:14px;font-weight:700;color:#1a1a1a}
    .member-pct{font-size:11px;color:#999;margin-top:1px}
    .tx-row{display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid #f5f5f5}
    .tx-row:last-child{border-bottom:none}
    .tx-cat{font-size:14px;font-weight:600;color:#1a1a1a}
    .tx-meta{font-size:11px;color:#999;margin-top:2px}
    .tx-amount{font-size:15px;font-weight:800}
    .open-btn{display:block;width:100%;padding:16px;border-radius:14px;font-size:16px;font-weight:800;text-decoration:none;color:#fff;background:linear-gradient(135deg,#5BAF8A,#2C6957);text-align:center;box-shadow:0 6px 20px rgba(44,105,87,.3);margin-top:4px;border:none;cursor:pointer}
    .store-btn{display:none;width:100%;padding:16px;border-radius:14px;font-size:16px;font-weight:800;text-decoration:none;color:#fff;background:linear-gradient(135deg,#1c1c1e,#3a3a3c);text-align:center;box-shadow:0 6px 20px rgba(0,0,0,.3);margin-top:8px;border:none;cursor:pointer}
    .footer{text-align:center;font-size:11px;color:#ccc;margin-top:16px}
    /* 微信提示遮罩 */
    #wechatTip{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.75);z-index:99;flex-direction:column;align-items:center;justify-content:center;padding:40px}
    .wechat-card{background:#fff;border-radius:20px;padding:28px 24px;text-align:center;max-width:280px}
    .wechat-card .arrow{font-size:40px;margin-bottom:12px}
    .wechat-card h3{font-size:17px;font-weight:700;margin-bottom:8px}
    .wechat-card p{font-size:13px;color:#999;line-height:1.7}
    .wechat-card button{margin-top:18px;padding:10px 28px;background:#2C6957;color:#fff;border:none;border-radius:10px;font-size:15px;font-weight:600}
  </style>
</head>
<body>
  <!-- 微信内提示浮层 -->
  <div id="wechatTip" style="display:none">
    <div class="wechat-card">
      <div class="arrow">↗️</div>
      <h3>请在浏览器中打开</h3>
      <p>点击右上角「···」<br>选择「在浏览器中打开」<br>然后再点击按钮即可唤起 App</p>
      <button onclick="document.getElementById('wechatTip').style.display='none'">知道了</button>
    </div>
  </div>

  <div class="header">
    <div class="header-top">
      <div class="proj-name">「${proj.name}」</div>
      <div class="badge">${memberCount} 位成员</div>
    </div>
    <div class="proj-meta">创建于 ${createdDate}</div>
    <div style="height:16px"></div>
    <div class="stats-row">
      <div class="stat">
        <div class="stat-val">¥${totalSpent.toFixed(0)}</div>
        <div class="stat-label">总支出</div>
      </div>
      <div class="divider-v"></div>
      <div class="stat">
        <div class="stat-val">${memberCount}</div>
        <div class="stat-label">成员数</div>
      </div>
      <div class="divider-v"></div>
      <div class="stat">
        <div class="stat-val">¥${memberCount > 0 ? (totalSpent / memberCount).toFixed(0) : 0}</div>
        <div class="stat-label">人均支出</div>
      </div>
    </div>
  </div>

  ${memberRows ? `<div class="card"><div class="card-title">👥 成员支出</div>${memberRows}</div>` : ''}

  ${recentRows ? `<div class="card"><div class="card-title">📋 最近账单</div>${recentRows}</div>` : ''}

  <button class="open-btn" id="openBtn">打开钱小满查看完整账单</button>
  <a class="store-btn" id="storeBtn" href="https://apps.apple.com/app/id6762140727">前往 App Store 下载钱小满</a>
  <div class="footer">由 钱小满 生成 · 仅限账本成员查看</div>

  <script>
    var deepLink = '${deepLink}';

    // H5 埋点：PV/UV 统计
    function getH5DeviceId(){var id=localStorage.getItem('h5_device_id');if(!id){id='h5_'+Math.random().toString(36).substr(2,9)+'_'+Date.now();localStorage.setItem('h5_device_id',id);}return id;}
    function trackPageView(t,c){try{fetch('/shared-api/h5/pageview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pageType:t,inviteCode:c,deviceId:getH5DeviceId(),userAgent:navigator.userAgent,referrer:document.referrer})});}catch(e){}}
    trackPageView('report_page','${inviteCode}');

    var isWechat = /micromessenger/i.test(navigator.userAgent);
    var openBtn = document.getElementById('openBtn');
    var storeBtn = document.getElementById('storeBtn');
    var wechatTip = document.getElementById('wechatTip');

    openBtn.addEventListener('click', function() {
      if (isWechat) {
        // 微信内置浏览器屏蔽自定义 scheme，引导用户去外部浏览器
        wechatTip.style.display = 'flex';
        return;
      }
      // Safari / Chrome：直接跳深链，超时后显示 App Store 备选
      window.location.href = deepLink;
      setTimeout(function() {
        if (!document.hidden) {
          openBtn.style.display = 'none';
          storeBtn.style.display = 'block';
        }
      }, 2000);
    });
  </script>
</body>
</html>`);
  } catch (err) {
    console.error('账单报告页失败:', err);
    res.status(500).send('服务错误');
  }
});

// H5 邀请落地页
router.get('/join-page/:inviteCode', async (req, res) => {
  try {
    const { inviteCode } = req.params;
    const [projects] = await db.execute(
      `SELECT p.name, COUNT(m.id) as member_count,
        (SELECT participant_name FROM mf_shared_project_members
         WHERE project_id = p.id ORDER BY joined_at ASC LIMIT 1) as creator_name
       FROM mf_shared_projects p
       LEFT JOIN mf_shared_project_members m ON p.id = m.project_id
       WHERE p.invite_code = ? AND p.is_deleted = 0
       GROUP BY p.id`,
      [inviteCode]
    );

    const projectName = projects.length > 0 ? projects[0].name : '共享账本';
    const memberCount = projects.length > 0 ? projects[0].member_count : 0;
    const creatorName = projects.length > 0 ? (projects[0].creator_name || projectName) : projectName;
    const deepLink = `moneyfull://join?code=${inviteCode}`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>和「重要的人」一起记账更有动力！</title>
  <meta property="og:title" content="和「重要的人」一起记账更有动力！">
  <meta property="og:description" content="${creatorName} 在钱小满创建了一个共享账本，邀请你一起记录共同开支">
  <meta property="og:image" content="https://originapex.cn/shared-api/assets/logo.png">
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Helvetica Neue",sans-serif;background:linear-gradient(160deg,#eaf6f0 0%,#f5f5f7 100%);min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:32px 24px}
    .card{background:#fff;border-radius:28px;padding:36px 28px 28px;width:100%;max-width:360px;box-shadow:0 8px 40px rgba(44,105,87,.12);text-align:center}
    .app-icon{width:72px;height:72px;border-radius:18px;margin:0 auto 16px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,.15)}
    .app-icon img{width:100%;height:100%;object-fit:cover}
    .tag{display:inline-block;background:#eaf6f0;color:#2C6957;font-size:11px;font-weight:700;padding:3px 10px;border-radius:20px;margin-bottom:12px;letter-spacing:.5px}
    h1{font-size:22px;font-weight:800;color:#1a1a1a;margin-bottom:6px;line-height:1.3}
    .inviter{font-size:14px;color:#666;margin-bottom:24px}
    .inviter strong{color:#2C6957}
    .divider{height:1px;background:#f0f0f0;margin:0 -28px 24px}
    .code-box{background:#f0f7f4;border-radius:14px;padding:16px 20px;margin-bottom:8px;display:flex;align-items:center;justify-content:space-between}
    .code-left{text-align:left}
    .code-label{font-size:11px;color:#999;margin-bottom:4px}
    .code{font-size:26px;font-weight:900;letter-spacing:5px;color:#2C6957}
    .member-badge{background:#2C6957;color:#fff;font-size:11px;font-weight:700;padding:4px 10px;border-radius:20px}
    .btn{display:block;width:100%;padding:17px;border-radius:16px;font-size:17px;font-weight:800;text-decoration:none;color:#fff;background:linear-gradient(135deg,#5BAF8A 0%,#2C6957 100%);margin:20px 0 12px;box-shadow:0 6px 20px rgba(44,105,87,.35);letter-spacing:.5px;text-align:center}
    .btn-store{background:linear-gradient(135deg,#1c1c1e 0%,#3a3a3c 100%);box-shadow:0 6px 20px rgba(0,0,0,.3)}
    .hint{font-size:12px;color:#ccc;line-height:1.7}
    .hint strong{color:#999}
    /* 微信引导浮层 */
    #wechatTip{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.78);z-index:99;flex-direction:column;align-items:center;justify-content:center;padding:40px}
    .wechat-card{background:#fff;border-radius:20px;padding:28px 24px;text-align:center;max-width:280px}
    .wechat-card .arrow{font-size:40px;margin-bottom:12px}
    .wechat-card h3{font-size:17px;font-weight:700;margin-bottom:8px}
    .wechat-card p{font-size:13px;color:#666;line-height:1.8}
    .wechat-card button{margin-top:18px;padding:10px 28px;background:#2C6957;color:#fff;border:none;border-radius:10px;font-size:15px;font-weight:600;cursor:pointer}
  </style>
</head>
<body>
  <!-- 微信内引导浮层 -->
  <div id="wechatTip" style="display:none">
    <div class="wechat-card">
      <div class="arrow">↗️</div>
      <h3>请在浏览器中打开</h3>
      <p>点击右上角「···」<br>选择「在浏览器中打开」<br>然后再点击按钮即可直接加入账本</p>
      <button onclick="document.getElementById('wechatTip').style.display='none'">知道了</button>
    </div>
  </div>
  <div class="card">
    <div class="app-icon">
      <img src="/shared-api/assets/logo.png" alt="钱小满" onerror="this.parentElement.innerHTML='💰'">
    </div>
    <div class="tag">钱小满 · 共享记账</div>
    <h1>和「重要的人」<br>一起记账更有动力！</h1>
    <p class="inviter"><strong>${creatorName}</strong> 在钱小满创建了一个共享账本，邀请你一起记录共同开支</p>
    <div class="divider"></div>
    <div class="code-box">
      <div class="code-left">
        <div class="code-label">邀请码</div>
        <div class="code">${inviteCode}</div>
      </div>
      <div class="member-badge">${memberCount} 人已加入</div>
    </div>
    <a class="btn" href="${deepLink}" id="openBtn">立即加入账本 →</a>
    <a class="btn btn-store" href="https://apps.apple.com/app/id6762140727" id="storeBtn" style="display:none">前往 App Store 下载钱小满</a>
    <p class="hint">如未自动跳转，请先下载钱小满 App，打开后输入邀请码<br><strong>${inviteCode}</strong> 即可加入</p>
  </div>
  <script>
    var deepLink = '${deepLink}';
    var appStoreUrl = 'https://apps.apple.com/app/id6762140727';
    var openBtn = document.getElementById('openBtn');
    var storeBtn = document.getElementById('storeBtn');

    // H5 埋点：PV/UV 统计
    function getH5DeviceId(){var id=localStorage.getItem('h5_device_id');if(!id){id='h5_'+Math.random().toString(36).substr(2,9)+'_'+Date.now();localStorage.setItem('h5_device_id',id);}return id;}
    function trackPageView(t,c){try{fetch('/shared-api/h5/pageview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pageType:t,inviteCode:c,deviceId:getH5DeviceId(),userAgent:navigator.userAgent,referrer:document.referrer})});}catch(e){}}
    trackPageView('invite_page','${inviteCode}');

    openBtn.addEventListener('click', function(e){
      e.preventDefault();
      // 微信内置浏览器屏蔽自定义 scheme，引导用户去外部浏览器
      if (/micromessenger/i.test(navigator.userAgent)) {
        document.getElementById('wechatTip').style.display = 'flex';
        return;
      }
      window.location.href = deepLink;
      setTimeout(function(){
        if (!document.hidden) {
          // App 未打开，先把邀请码写入剪贴板（iOS App 冷启后可自动读取）
          try { navigator.clipboard.writeText('${inviteCode}'); } catch(e) {
            try { var t=document.createElement('textarea'); t.value='moneyfull-invite:${inviteCode}'; document.body.appendChild(t); t.select(); document.execCommand('copy'); document.body.removeChild(t); } catch(e2) {}
          }
          openBtn.style.display = 'none';
          storeBtn.style.display = 'block';
        }
      }, 2000);
    });
  </script>
</body>
</html>`);
  } catch (error) {
    console.error('落地页生成失败:', error);
    res.status(500).send('服务错误');
  }
});

module.exports = router;
