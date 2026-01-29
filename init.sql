ALTER TABLE `users`
	ADD lives INT NULL DEFAULT (NULL),
	ADD INDEX `idx_users_lives` (`lives`);