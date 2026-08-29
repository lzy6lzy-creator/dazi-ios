CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE beta_signups (
	id UUID NOT NULL, 
	name VARCHAR(80) NOT NULL, 
	email VARCHAR(160) NOT NULL, 
	contact VARCHAR(120), 
	city VARCHAR(80), 
	device VARCHAR(120), 
	activity_interests VARCHAR[], 
	note TEXT, 
	source VARCHAR(40) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	ip_address VARCHAR(64), 
	user_agent TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);
CREATE TABLE invitation_programs (
	id INTEGER NOT NULL, 
	registration_mode VARCHAR(20) NOT NULL, 
	launch_city_code VARCHAR(12) NOT NULL, 
	qualified_target INTEGER NOT NULL, 
	location_valid_days INTEGER NOT NULL, 
	qualified_user_count INTEGER NOT NULL, 
	ios_distribution_mode VARCHAR(20) NOT NULL, 
	testflight_public_url TEXT, 
	app_store_url TEXT, 
	transitioned_at TIMESTAMP WITH TIME ZONE, 
	updated_by VARCHAR(100), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);
CREATE TABLE prompt_templates (
	id UUID NOT NULL, 
	name VARCHAR(50) NOT NULL, 
	content TEXT NOT NULL, 
	description TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);
CREATE TABLE service_reminders (
	id UUID NOT NULL, 
	slug VARCHAR(80) NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	category VARCHAR(40) NOT NULL, 
	provider VARCHAR(80), 
	reminder_type VARCHAR(30) NOT NULL, 
	due_date DATE, 
	date_precision VARCHAR(20) NOT NULL, 
	recurrence_months INTEGER, 
	reminder_days VARCHAR(80) NOT NULL, 
	auto_renew BOOLEAN NOT NULL, 
	owner VARCHAR(80), 
	action_url VARCHAR(500), 
	notes TEXT, 
	source VARCHAR(40) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	last_verified_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);
CREATE TABLE site_feedback (
	id UUID NOT NULL, 
	category VARCHAR(40) NOT NULL, 
	content TEXT NOT NULL, 
	contact VARCHAR(160), 
	source VARCHAR(40) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	ip_address VARCHAR(64), 
	user_agent TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);
CREATE TABLE users (
	id UUID NOT NULL, 
	phone VARCHAR(20), 
	name VARCHAR(50) NOT NULL, 
	gender VARCHAR(10), 
	birth_year INTEGER, 
	birth_date DATE, 
	bio TEXT, 
	avatar_url TEXT, 
	avatar_emoji VARCHAR(10) DEFAULT '😊' NOT NULL, 
	interests VARCHAR[], 
	city VARCHAR(50), 
	occupation VARCHAR(100), 
	custom_interests TEXT, 
	welcome_disturb BOOLEAN NOT NULL, 
	profile_event_visibility VARCHAR(20) DEFAULT 'partial' NOT NULL, 
	embedding VECTOR(768), 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (phone)
);
CREATE TABLE agent_chat_messages (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	role VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE agent_memories (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	type VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	confidence FLOAT NOT NULL, 
	source VARCHAR(20) NOT NULL, 
	source_event_id UUID, 
	key VARCHAR(100), 
	category VARCHAR(40), 
	scope VARCHAR(20) NOT NULL, 
	value JSONB, 
	occurrence_count INTEGER NOT NULL, 
	last_seen_at TIMESTAMP WITH TIME ZONE, 
	expires_at TIMESTAMP WITH TIME ZONE, 
	status VARCHAR(20) NOT NULL, 
	superseded_by_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE agents (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	name VARCHAR(50) NOT NULL, 
	emoji VARCHAR(10), 
	avatar_url TEXT, 
	personality TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE events (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	description TEXT, 
	activity_type VARCHAR(50) NOT NULL, 
	start_time TIMESTAMP WITH TIME ZONE, 
	end_time TIMESTAMP WITH TIME ZONE, 
	location VARCHAR(200), 
	city VARCHAR(50), 
	preferences VARCHAR[], 
	constraints VARCHAR[], 
	clarification_answers JSONB, 
	age_filter_min INTEGER, 
	age_filter_max INTEGER, 
	age_filter_mode VARCHAR(20), 
	status VARCHAR(20) NOT NULL, 
	matched_event_id UUID, 
	match_score FLOAT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE, 
	match_round INTEGER NOT NULL, 
	embedding VECTOR(768), 
	city_normalized VARCHAR(50), 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE location_verifications (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	city_code VARCHAR(12), 
	is_launch_city BOOLEAN NOT NULL, 
	accuracy_meters FLOAT NOT NULL, 
	risk_flags JSONB NOT NULL, 
	verified_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE match_blocklists (
	id UUID NOT NULL, 
	event_a_id UUID, 
	event_b_id UUID, 
	user_a_id UUID NOT NULL, 
	user_b_id UUID NOT NULL, 
	reason VARCHAR(40) NOT NULL, 
	source_room_id UUID, 
	source_request_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_a_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_b_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE push_device_tokens (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	token VARCHAR(255) NOT NULL, 
	platform VARCHAR(20) NOT NULL, 
	environment VARCHAR(20) NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE user_invitation_accounts (
	user_id UUID NOT NULL, 
	code VARCHAR(8) NOT NULL, 
	granted_total INTEGER NOT NULL, 
	consumed_total INTEGER NOT NULL, 
	reserved_total INTEGER NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	first_qualified_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (user_id), 
	CONSTRAINT ck_invitation_account_granted_nonnegative CHECK (granted_total >= 0), 
	CONSTRAINT ck_invitation_account_consumed_nonnegative CHECK (consumed_total >= 0), 
	CONSTRAINT ck_invitation_account_reserved_nonnegative CHECK (reserved_total >= 0), 
	CONSTRAINT ck_invitation_account_balance_nonnegative CHECK (granted_total - consumed_total - reserved_total >= 0), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE chat_rooms (
	id UUID NOT NULL, 
	event_id_a UUID, 
	event_id_b UUID, 
	match_summary TEXT, 
	agent_dialogue TEXT, 
	match_type VARCHAR(20) NOT NULL, 
	phase VARCHAR(30) NOT NULL, 
	a2a_candidate_rank INTEGER, 
	a2a_result VARCHAR(40), 
	is_active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	closed_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(event_id_a) REFERENCES events (id) ON DELETE SET NULL, 
	FOREIGN KEY(event_id_b) REFERENCES events (id) ON DELETE SET NULL
);
CREATE TABLE event_feedbacks (
	id UUID NOT NULL, 
	event_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	experience_rating INTEGER NOT NULL, 
	experience_comment TEXT, 
	partner_rating INTEGER, 
	partner_comment TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_event_feedback_event_user UNIQUE (event_id, user_id), 
	FOREIGN KEY(event_id) REFERENCES events (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE event_gallery_items (
	id UUID NOT NULL, 
	event_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	photo_urls JSONB NOT NULL, 
	is_displayed BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_event_gallery_event_user UNIQUE (event_id, user_id), 
	FOREIGN KEY(event_id) REFERENCES events (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE event_memories (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	event_id UUID NOT NULL, 
	key VARCHAR(100) NOT NULL, 
	type VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	value JSONB, 
	category VARCHAR(40) NOT NULL, 
	source VARCHAR(20) NOT NULL, 
	confidence FLOAT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(event_id) REFERENCES events (id) ON DELETE CASCADE
);
CREATE TABLE match_logs (
	id UUID NOT NULL, 
	event_a_id UUID NOT NULL, 
	event_b_id UUID NOT NULL, 
	stage VARCHAR(30) NOT NULL, 
	score FLOAT NOT NULL, 
	reasons VARCHAR[], 
	issues VARCHAR[], 
	score_breakdown JSONB, 
	dialogue_log TEXT, 
	result VARCHAR(20) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(event_a_id) REFERENCES events (id) ON DELETE CASCADE, 
	FOREIGN KEY(event_b_id) REFERENCES events (id) ON DELETE CASCADE
);
CREATE TABLE memory_evidence (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	memory_id UUID, 
	event_id UUID, 
	chat_message_id UUID, 
	source VARCHAR(20) NOT NULL, 
	source_text TEXT, 
	event_memory_ids JSONB, 
	confidence_delta FLOAT NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(memory_id) REFERENCES agent_memories (id) ON DELETE SET NULL
);
CREATE TABLE passive_match_requests (
	id UUID NOT NULL, 
	event_id UUID NOT NULL, 
	requester_user_id UUID NOT NULL, 
	target_user_id UUID NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	similarity FLOAT, 
	message TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	responded_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(event_id) REFERENCES events (id) ON DELETE CASCADE, 
	FOREIGN KEY(requester_user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(target_user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE signup_admissions (
	id UUID NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	phone VARCHAR(20) NOT NULL, 
	admission_type VARCHAR(20) NOT NULL, 
	registration_mode VARCHAR(20) NOT NULL, 
	invitation_account_user_id UUID, 
	status VARCHAR(20) NOT NULL, 
	failed_attempts INTEGER NOT NULL, 
	install_id_hash VARCHAR(64), 
	ip_hash VARCHAR(64), 
	location_city_code VARCHAR(12), 
	location_is_launch_city BOOLEAN, 
	location_accuracy_meters FLOAT, 
	location_verified_at TIMESTAMP WITH TIME ZONE, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	consumed_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(invitation_account_user_id) REFERENCES user_invitation_accounts (user_id) ON DELETE SET NULL
);
CREATE TABLE chat_messages (
	id UUID NOT NULL, 
	room_id UUID NOT NULL, 
	sender_id UUID NOT NULL, 
	sender_type VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	mentions VARCHAR[], 
	visibility VARCHAR(30) NOT NULL, 
	recipient_user_id UUID, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(room_id) REFERENCES chat_rooms (id) ON DELETE CASCADE, 
	FOREIGN KEY(sender_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(recipient_user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE chat_room_members (
	id UUID NOT NULL, 
	room_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	agent_id UUID, 
	role VARCHAR(20) NOT NULL, 
	is_owner BOOLEAN NOT NULL, 
	joined_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	last_read_at TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(room_id) REFERENCES chat_rooms (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(agent_id) REFERENCES agents (id) ON DELETE SET NULL
);
CREATE TABLE chat_room_votes (
	id UUID NOT NULL, 
	room_id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	vote VARCHAR(10) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_chat_room_votes_room_user UNIQUE (room_id, user_id), 
	FOREIGN KEY(room_id) REFERENCES chat_rooms (id) ON DELETE CASCADE, 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);
CREATE TABLE invitation_ledger (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	entry_type VARCHAR(30) NOT NULL, 
	amount INTEGER NOT NULL, 
	idempotency_key VARCHAR(160) NOT NULL, 
	source_event_id UUID, 
	source_chat_room_id UUID, 
	invitee_user_id UUID, 
	location_verification_id UUID, 
	operator_id VARCHAR(100), 
	reason TEXT, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	UNIQUE (idempotency_key), 
	FOREIGN KEY(source_event_id) REFERENCES events (id) ON DELETE SET NULL, 
	FOREIGN KEY(source_chat_room_id) REFERENCES chat_rooms (id) ON DELETE SET NULL, 
	UNIQUE (invitee_user_id), 
	FOREIGN KEY(invitee_user_id) REFERENCES users (id) ON DELETE SET NULL, 
	FOREIGN KEY(location_verification_id) REFERENCES location_verifications (id) ON DELETE SET NULL
);
CREATE TABLE invitation_milestones (
	id UUID NOT NULL, 
	user_id UUID NOT NULL, 
	milestone_type VARCHAR(30) NOT NULL, 
	status VARCHAR(30) NOT NULL, 
	source_event_id UUID, 
	source_chat_room_id UUID, 
	settled_at TIMESTAMP WITH TIME ZONE, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_invitation_milestone_user_type UNIQUE (user_id, milestone_type), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(source_event_id) REFERENCES events (id) ON DELETE SET NULL, 
	FOREIGN KEY(source_chat_room_id) REFERENCES chat_rooms (id) ON DELETE SET NULL
);
CREATE INDEX ix_beta_signups_email ON beta_signups (email);
CREATE INDEX ix_beta_signups_email_created ON beta_signups (email, created_at);
CREATE INDEX ix_beta_signups_status ON beta_signups (status);
CREATE UNIQUE INDEX ix_prompt_templates_name ON prompt_templates (name);
CREATE INDEX ix_service_reminders_category ON service_reminders (category);
CREATE INDEX ix_service_reminders_category_due ON service_reminders (category, due_date);
CREATE INDEX ix_service_reminders_due_date ON service_reminders (due_date);
CREATE UNIQUE INDEX ix_service_reminders_slug ON service_reminders (slug);
CREATE INDEX ix_service_reminders_status ON service_reminders (status);
CREATE INDEX ix_service_reminders_status_due ON service_reminders (status, due_date);
CREATE INDEX ix_site_feedback_category ON site_feedback (category);
CREATE INDEX ix_site_feedback_category_created ON site_feedback (category, created_at);
CREATE INDEX ix_site_feedback_status ON site_feedback (status);
CREATE INDEX ix_site_feedback_status_created ON site_feedback (status, created_at);
CREATE INDEX ix_agent_chat_messages_user_id ON agent_chat_messages (user_id);
CREATE INDEX ix_agent_memories_key ON agent_memories (key);
CREATE INDEX ix_agent_memories_user_id ON agent_memories (user_id);
CREATE INDEX ix_events_activity_type ON events (activity_type);
CREATE INDEX ix_events_city ON events (city);
CREATE INDEX ix_events_city_normalized ON events (city_normalized);
CREATE INDEX ix_events_status ON events (status);
CREATE INDEX ix_events_user_id ON events (user_id);
CREATE INDEX ix_location_verifications_user_id ON location_verifications (user_id);
CREATE INDEX ix_match_blocklists_event_pair ON match_blocklists (event_a_id, event_b_id);
CREATE INDEX ix_match_blocklists_user_a_id ON match_blocklists (user_a_id);
CREATE INDEX ix_match_blocklists_user_b_id ON match_blocklists (user_b_id);
CREATE INDEX ix_match_blocklists_user_pair ON match_blocklists (user_a_id, user_b_id);
CREATE INDEX ix_push_device_tokens_is_active ON push_device_tokens (is_active);
CREATE UNIQUE INDEX ix_push_device_tokens_token ON push_device_tokens (token);
CREATE INDEX ix_push_device_tokens_user_id ON push_device_tokens (user_id);
CREATE UNIQUE INDEX ix_user_invitation_accounts_code ON user_invitation_accounts (code);
CREATE INDEX ix_event_feedbacks_event_id ON event_feedbacks (event_id);
CREATE INDEX ix_event_feedbacks_user_id ON event_feedbacks (user_id);
CREATE INDEX ix_event_gallery_items_event_id ON event_gallery_items (event_id);
CREATE INDEX ix_event_gallery_items_user_id ON event_gallery_items (user_id);
CREATE INDEX ix_event_memories_event_id ON event_memories (event_id);
CREATE INDEX ix_event_memories_key ON event_memories (key);
CREATE INDEX ix_event_memories_user_id ON event_memories (user_id);
CREATE INDEX ix_match_logs_event_a_id ON match_logs (event_a_id);
CREATE INDEX ix_match_logs_event_b_id ON match_logs (event_b_id);
CREATE INDEX ix_memory_evidence_memory_id ON memory_evidence (memory_id);
CREATE INDEX ix_memory_evidence_user_id ON memory_evidence (user_id);
CREATE INDEX ix_passive_match_requests_event_id ON passive_match_requests (event_id);
CREATE INDEX ix_passive_match_requests_requester_user_id ON passive_match_requests (requester_user_id);
CREATE INDEX ix_passive_match_requests_status ON passive_match_requests (status);
CREATE INDEX ix_passive_match_requests_target_status ON passive_match_requests (target_user_id, status);
CREATE INDEX ix_passive_match_requests_target_user_id ON passive_match_requests (target_user_id);
CREATE INDEX ix_signup_admissions_expires_at ON signup_admissions (expires_at);
CREATE INDEX ix_signup_admissions_phone ON signup_admissions (phone);
CREATE INDEX ix_signup_admissions_status ON signup_admissions (status);
CREATE UNIQUE INDEX ix_signup_admissions_token_hash ON signup_admissions (token_hash);
CREATE INDEX ix_chat_messages_recipient_user_id ON chat_messages (recipient_user_id);
CREATE INDEX ix_chat_messages_room_created ON chat_messages (room_id, created_at);
CREATE INDEX ix_chat_messages_room_id ON chat_messages (room_id);
CREATE INDEX ix_chat_room_members_agent_id ON chat_room_members (agent_id);
CREATE INDEX ix_chat_room_members_room_id ON chat_room_members (room_id);
CREATE INDEX ix_chat_room_members_user_id ON chat_room_members (user_id);
CREATE INDEX ix_chat_room_votes_room_id ON chat_room_votes (room_id);
CREATE INDEX ix_invitation_ledger_user_id ON invitation_ledger (user_id);
CREATE INDEX ix_invitation_milestones_user_id ON invitation_milestones (user_id);
