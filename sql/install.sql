-- Schéma initial de persistance pour MDT-SAS.
-- À appliquer dans la base dédiée au serveur avant de brancher oxmysql.
-- Toutes les dates sont enregistrées en UTC Unix ou DATETIME selon la colonne.

CREATE TABLE IF NOT EXISTS mdt_sas_agents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  identifier VARCHAR(100) NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  grade VARCHAR(80) NOT NULL DEFAULT 'agent',
  on_duty TINYINT(1) NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'unavailable',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mdt_sas_agent_identifier (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mdt_sas_partners (
  id VARCHAR(80) NOT NULL,
  name VARCHAR(150) NOT NULL,
  address VARCHAR(255) NOT NULL DEFAULT '',
  x DOUBLE NULL,
  y DOUBLE NULL,
  z DOUBLE NULL,
  daily_target INT UNSIGNED NOT NULL DEFAULT 4,
  notes TEXT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mdt_sas_dispatches (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(90) NOT NULL,
  description TEXT NULL,
  partner_id VARCHAR(80) NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'open',
  created_by VARCHAR(100) NOT NULL,
  assigned_identifier VARCHAR(100) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_mdt_sas_dispatch_status (status),
  KEY idx_mdt_sas_dispatch_partner (partner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mdt_sas_passages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  partner_id VARCHAR(80) NOT NULL,
  agent_identifier VARCHAR(100) NOT NULL,
  agent_name VARCHAR(100) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'pending_evidence',
  evidence_reference VARCHAR(500) NULL,
  x DOUBLE NULL,
  y DOUBLE NULL,
  z DOUBLE NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  passage_day DATE NOT NULL,
  PRIMARY KEY (id),
  KEY idx_mdt_sas_passage_day_partner (passage_day, partner_id),
  KEY idx_mdt_sas_passage_agent (agent_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mdt_sas_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(120) NOT NULL,
  body MEDIUMTEXT NOT NULL,
  author_identifier VARCHAR(100) NOT NULL,
  author_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mdt_sas_report_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mdt_sas_audit (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  actor_identifier VARCHAR(100) NOT NULL,
  actor_name VARCHAR(100) NOT NULL,
  action VARCHAR(100) NOT NULL,
  details JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mdt_sas_audit_created (created_at),
  KEY idx_mdt_sas_audit_actor (actor_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
