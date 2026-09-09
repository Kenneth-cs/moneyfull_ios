-- H5 页面访问日志表（PV/UV 统计）
-- 执行方式：登录 MySQL 后在 originapex_db 库下运行

CREATE TABLE IF NOT EXISTS mf_shared_page_views (
    id             BIGINT AUTO_INCREMENT PRIMARY KEY,
    page_type      VARCHAR(50) NOT NULL,
    invite_code    VARCHAR(8),
    project_id     VARCHAR(36),
    device_id      VARCHAR(100) NOT NULL,
    user_agent     VARCHAR(500),
    ip_address     VARCHAR(45),
    referrer       VARCHAR(500),
    is_unique      TINYINT(1) DEFAULT 1,
    visited_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_code_date (invite_code, visited_at),
    INDEX idx_project_date (project_id, visited_at),
    INDEX idx_page_date (page_type, visited_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
