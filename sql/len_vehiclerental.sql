CREATE TABLE IF NOT EXISTS `len_rentals` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `plate` VARCHAR(8) NOT NULL,
  `model` VARCHAR(40) NOT NULL,
  `station` INT NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `base_price` INT NOT NULL DEFAULT 0,
  `deposit` INT NOT NULL DEFAULT 0,
  `insurance` VARCHAR(20) NOT NULL DEFAULT 'none',
  `paid` INT NOT NULL DEFAULT 0,
  `damage_total` INT NOT NULL DEFAULT 0,
  `late_fees` INT NOT NULL DEFAULT 0,
  `km_total` INT NOT NULL DEFAULT 0,
  `started_at` DATETIME NULL DEFAULT NULL,
  `expires_at` DATETIME NULL DEFAULT NULL,
  `ended_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_rentals_identifier` (`identifier`),
  INDEX `idx_rentals_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `len_rental_debts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `reason` VARCHAR(30) NOT NULL,
  `created_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_debts_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
