const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去掉易混淆的 0/O/1/I

async function generateUniqueCode(db) {
  for (let attempt = 0; attempt < 10; attempt++) {
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += CHARS[Math.floor(Math.random() * CHARS.length)];
    }
    const [rows] = await db.execute(
      'SELECT id FROM mf_shared_projects WHERE invite_code = ?', [code]
    );
    if (rows.length === 0) return code;
  }
  throw new Error('邀请码生成失败，请重试');
}

module.exports = { generateUniqueCode };
