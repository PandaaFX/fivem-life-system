ALTER TABLE `users`
	ADD lifes INT NULL DEFAULT (NULL),
	ADD INDEX `idx_users_lifes` (`lifes`);