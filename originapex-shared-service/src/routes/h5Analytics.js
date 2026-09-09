const express = require('express');
const router = express.Router();
const db = require('../db');

// 记录页面访问（PV / UV）
router.post('/pageview', async (req, res) => {
  try {
    const { pageType, inviteCode, projectId, deviceId, userAgent, referrer } = req.body;

    if (!pageType || !deviceId) {
      return res.status(400).json({ error: '缺少必要参数' });
    }

    // 判断是否当天首次访问（UV）
    const [existing] = await db.execute(
      `SELECT id FROM mf_shared_page_views
       WHERE device_id = ? AND page_type = ? AND DATE(visited_at) = CURDATE()`,
      [deviceId, pageType]
    );

    const isUnique = existing.length === 0;

    await db.execute(
      `INSERT INTO mf_shared_page_views
       (page_type, invite_code, project_id, device_id, user_agent, ip_address, referrer, is_unique)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [pageType, inviteCode || null, projectId || null, deviceId, userAgent || null, req.ip, referrer || null, isUnique]
    );

    res.json({ ok: true, isUnique });
  } catch (error) {
    console.error('记录页面访问失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 查询页面统计（PV / UV）
router.get('/stats', async (req, res) => {
  try {
    const { pageType, inviteCode, startDate, endDate } = req.query;

    let whereClause = 'WHERE 1=1';
    const params = [];

    if (pageType) {
      whereClause += ' AND page_type = ?';
      params.push(pageType);
    }
    if (inviteCode) {
      whereClause += ' AND invite_code = ?';
      params.push(inviteCode);
    }
    if (startDate) {
      whereClause += ' AND visited_at >= ?';
      params.push(startDate);
    }
    if (endDate) {
      whereClause += ' AND visited_at <= ?';
      params.push(endDate + ' 23:59:59');
    }

    const [totals] = await db.execute(
      `SELECT COUNT(*) as totalPV, COALESCE(SUM(is_unique), 0) as totalUV
       FROM mf_shared_page_views ${whereClause}`,
      params
    );

    const [daily] = await db.execute(
      `SELECT DATE(visited_at) as date, COUNT(*) as pv, COALESCE(SUM(is_unique), 0) as uv
       FROM mf_shared_page_views ${whereClause}
       GROUP BY DATE(visited_at)
       ORDER BY date`,
      params
    );

    res.json({
      pageType: pageType || null,
      inviteCode: inviteCode || null,
      totalPV: totals[0].totalPV || 0,
      totalUV: totals[0].totalUV || 0,
      dailyStats: daily
    });
  } catch (error) {
    console.error('查询统计失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

// 查询项目维度统计（聚合）
router.get('/stats/project/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { startDate, endDate } = req.query;

    let whereClause = 'WHERE project_id = ?';
    const params = [projectId];

    if (startDate) {
      whereClause += ' AND visited_at >= ?';
      params.push(startDate);
    }
    if (endDate) {
      whereClause += ' AND visited_at <= ?';
      params.push(endDate + ' 23:59:59');
    }

    const [totals] = await db.execute(
      `SELECT COUNT(*) as totalPV, COALESCE(SUM(is_unique), 0) as totalUV
       FROM mf_shared_page_views ${whereClause}`,
      params
    );

    const [byType] = await db.execute(
      `SELECT page_type, COUNT(*) as pv, COALESCE(SUM(is_unique), 0) as uv
       FROM mf_shared_page_views ${whereClause}
       GROUP BY page_type`,
      params
    );

    const byPageType = {};
    byType.forEach(row => {
      byPageType[row.page_type] = { pv: row.pv, uv: row.uv };
    });

    const inviteUV = byPageType['invite_page']?.uv || 0;
    const joinUV = byPageType['join_success']?.uv || 0;
    const conversionRate = inviteUV > 0 ? parseFloat((joinUV / inviteUV).toFixed(3)) : 0;

    res.json({
      projectId,
      totalPV: totals[0].totalPV || 0,
      totalUV: totals[0].totalUV || 0,
      byPageType,
      conversionRate
    });
  } catch (error) {
    console.error('查询项目统计失败:', error);
    res.status(500).json({ error: '服务器内部错误' });
  }
});

module.exports = router;
