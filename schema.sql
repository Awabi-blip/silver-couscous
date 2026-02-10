-- Types FOR USERS TABLE
CREATE TYPE "users_badge" AS ENUM ('The Architect', 'Side Quest Hero', 'All or Nothing', 'Vanilla Latte',
'Overthinker', 'Pixel Perfect', 'Void Cat', 'Invisible', 'Eclipse');

-- Architect : Autism
-- Side Quest Hero : ADHD
-- All or Nothing :
-- Vanilla Late : Neurotypical
-- Overthinker : Anxiety Syndrome
-- Pixel Perfect : OCD
-- Void Cat :
-- Invisible : Introvert
-- Eclipse : Bipolar Disorder

CREATE TYPE "users_status" AS ENUM ('Active', 'Moon Walking', 'Sensory Overload', 'Electric');

CREATE TABLE IF NOT EXISTS "users" (
    "id" SERIAL,
    "username" VARCHAR(24) NOT NULL UNIQUE,
    "password" VARCHAR(100) NOT NULL,
    "display_name" VARCHAR(24),
    "badge" users_badge DEFAULT 'Vanilla Latte',
    "pfp" VARCHAR(255) DEFAULT 'xyz.jpg',
    "bio" VARCHAR (500),
    "status" users_status DEFAULT 'Active',
    "verified" BOOLEAN NOT NULL,
    PRIMARY KEY ("id")
);
-- TYPES FOR SERVERS TABLE
--
CREATE TYPE server_security_level AS ENUM ('Level 1', 'Level 2');

CREATE TABLE IF NOT EXISTS "servers" (
    "id" SERIAL,
    "server_name" VARCHAR(24) NOT NULL UNIQUE,
    "display_name" VARCHAR(24) NOT NULL,
    "banner" VARCHAR(255) DEFAULT 'server_banner.jpg',
    "icon" VARCHAR(255) DEFAULT 'server_icon.jpg',
    "description" VARCHAR(500),
    "security_level" server_security_level DEFAULT 'Level 1',
    PRIMARY KEY ("id")
);

CREATE TYPE "role_name" AS ENUM ('Member', 'Admin', 'Muted');

-- Look UP Table
CREATE TABLE IF NOT EXISTS "roles" (
    "id" INT,
    "name" role_name UNIQUE,
    "permissions" TEXT[],
    PRIMARY KEY ("id")
);

INSERT INTO roles (id, name, permissions) VALUES
(1, 'Muted', ARRAY['Read']),
(2, 'Member', ARRAY['Read', 'Write', 'Delete']),
(3, 'Admin', ARRAY['Read', 'Write', 'Delete', 'Ban_Users', 'Update_Server_Settings']);

CREATE TABLE IF NOT EXISTS "users_in_servers" (
    "user_id" INT,
    "server_id" INT,
    "role_id" INT DEFAULT 2,
    PRIMARY KEY ("user_id", "server_id"),
    FOREIGN KEY ("user_id") REFERENCES "users"("id"),
    FOREIGN KEY ("server_id") REFERENCES "servers"("id"),
    FOREIGN KEY ("role_id") REFERENCES "roles"("id")
);

CREATE TABLE IF NOT EXISTS "messages_in_servers"(
    "id" SERIAL,
    "user_id" INT,
    "server_id" INT,
    "message" VARCHAR (2000) NOT NULL,
    "attachment" VARCHAR(255) DEFAULT NULL,
    "sent_at" TIMESTAMPTZ(0) DEFAULT now(),
    "is_deleted" BOOLEAN DEFAULT FALSE NOT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("user_id") REFERENCES "users"("id"),
    FOREIGN KEY ("server_id") REFERENCES "servers"("id")
);

CREATE TABLE IF NOT EXISTS "audit_logs" (
    "id" SERIAL,
    "message_id" INT,
    "deleted_of_id" INT,
    "deleted_by_id" INT,
    "server_id" INT,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("message_id") REFERENCES "messages_in_servers"("id"),
    FOREIGN KEY ("server_id") REFERENCES "servers"("id"),
    FOREIGN KEY ("deleted_of_id") REFERENCES "users"("id"),
    FOREIGN KEY ("deleted_by_id") REFERENCES "users"("id")
);

CREATE TABLE IF NOT EXISTS "messages_in_dms"(
    "id" SERIAL,
    "author_id" INT,
    "receiver_id" INT,
    "message" VARCHAR (2000) NOT NULL,
    "attachment" VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY ("id"),
    FOREIGN KEY ("author_id") REFERENCES "users"("id"),
    FOREIGN KEY ("receiver_id") REFERENCES "users"("id")
);

CREATE TABLE IF NOT EXISTS "points_balance"(
    "id" SERIAL,
    "user_id" INT,
    "balance" DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY("id"),
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
);

CREATE TABLE IF NOT EXISTS "points_transactions"(
    "id" BIGSERIAL,
    "sender_id" INT,
    "receiver_id" INT,
    "amount_sent" DECIMAL (8,2) NOT NULL,
    PRIMARY KEY("id"),
    FOREIGN KEY ("sender_id") REFERENCES "users"("id"),
    FOREIGN KEY ("receiver_id") REFERENCES "users"("id")
);

CREATE TYPE gifts AS ENUM ('earplugs', 'headphones', 'dim lights', 'fidget spinners', 'weighted blanket', 'fragrance');

CREATE TABLE IF NOT EXISTS gift_inventory (
    "type" gifts NOT NULL UNIQUE,
    "price" DECIMAL(7,2) NOT NULL,
    PRIMARY KEY("type")
);

INSERT INTO gift_inventory(type,price)
VALUES ('earplugs', 30.00),
('headphones', 150.00),
('dim lights', 30.00),
('fidget spinners', 50.00),
('weighted blanket', 250.00),
('fragrance', 300.00);

CREATE TABLE IF NOT EXISTS "gifts_transactions" (
    "id" BIGSERIAL,
    "sender_id" INT,
    "receiver_id" INT,
    "gift_type" gifts,
    PRIMARY KEY("id"),
    FOREIGN KEY ("sender_id") REFERENCES "users"("id"),
    FOREIGN KEY ("receiver_id") REFERENCES "users"("id"),
    FOREIGN KEY ("gift_type") REFERENCES "gift_inventory"("type")
);

CREATE TABLE IF NOT EXISTS "friends" (
    "id" SERIAL,
    "user_1_id" INT,
    "user_2_id" INT,
    PRIMARY KEY ("user_1_id", "user_2_id"),
    FOREIGN KEY ("user_1_id") REFERENCES "users"("id"),
    FOREIGN KEY ("user_2_id") REFERENCES "users"("id"),
    CHECK ("user_1_id" <> "user_2_id")
);

--TO check weather user can send messages
CREATE OR REPLACE FUNCTION get_user_friends(f_user_id INT)
RETURNS TABLE (
    friends_name VARCHAR(24)
    )
AS $$
BEGIN
    RETURN QUERY
    SELECT
    users.username FROM friends
    JOIN users ON friends.user_2_id = users.id
    WHERE friends.user_1_id = f_user_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_user_servers(f_user_id INT)
RETURNS TABLE (
    servers_name VARCHAR(24),
    role_in_server role_name,
    permissions TEXT[]
)
AS $$
BEGIN
    RETURN QUERY
    SELECT servers.display_name as server_name, roles.name as role_name, roles.permissions FROM users
    JOIN users_in_servers ON users.id = users_in_servers.user_id
    JOIN servers ON servers.id = users_in_servers.server_id
    JOIN roles ON roles.id = users_in_servers.role_id
    WHERE users_in_servers.user_id = f_user_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_server_members(f_server_id INT)
RETURNS TABLE(
    user_id INT,
    username VARCHAR(24),
    has_role role_name
)
AS $$
BEGIN
    RETURN QUERY
    SELECT  users_in_servers.user_id, users.username, roles.name
    FROM users
    JOIN users_in_servers
    ON users.id = users_in_servers.user_id
    JOIN roles
    ON users_in_servers.role_id = roles.id
    WHERE users_in_servers.server_id = f_server_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_user_integrity()
RETURNS TRIGGER AS $$
DECLARE
    v_verification BOOLEAN;
    v_security_level TEXT;
BEGIN
    v_verification := (SELECT verified FROM users WHERE id = NEW.user_id);
    v_security_level := (SELECT security_level FROM servers WHERE id = NEW.server_id);

    IF v_verification = FALSE AND v_security_level = 'Level 2' THEN
         RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_user_integrity
BEFORE INSERT ON "users_in_servers"
FOR EACH ROW
EXECUTE FUNCTION check_user_integrity();

CREATE OR REPLACE PROCEDURE make_friends(p_user_1_id INT, p_user_2_id INT)
AS $$
BEGIN
    IF p_user_1_id = p_user_2_id
       THEN
           RAISE EXCEPTION 'a user cannot add them selves as friends!';
    END IF;

    INSERT INTO friends (user_1_id, user_2_id)
    VALUES (p_user_1_id, p_user_2_id);

    INSERT INTO friends (user_1_id, user_2_id)
    VALUES (p_user_2_id, p_user_1_id);

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE insert_points_balance(p_user_id INT, p_amount DECIMAL(8,2))
AS $$
DECLARE
p_verified BOOLEAN;
BEGIN
    p_verified := (SELECT verified FROM users WHERE id = p_user_id);

    IF p_verified = FALSE THEN
        RAISE EXCEPTION 'this action cannot be done';
    END IF;

    INSERT INTO points_balance (user_id, balance)
    VALUES (p_user_id, p_amount);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE make_points_transactions(p_sender_id INT, p_receiver_id INT, p_amount_sent DECIMAL(8,2))
AS $$
DECLARE
p_sender_balance NUMERIC;
BEGIN
    IF p_amount_sent <= 0 THEN
        RAISE EXCEPTION
            'not possible';
    END IF;

    p_sender_balance := (SELECT balance FROM points_balance WHERE user_id = p_sender_id FOR UPDATE);

    IF p_sender_balance IS NULL THEN
        RAISE EXCEPTION 'no balance added, hence no transactions must take place, fair as all things must be. period.';
    END IF;

    IF p_sender_balance <= 0 OR P_sender_balance < p_amount_sent THEN
        RAISE EXCEPTION 'not enough balance';
    END IF;

    UPDATE points_balance
    SET balance = balance - p_amount_sent
    WHERE user_id = p_sender_id;

    UPDATE points_balance
    SET balance = balance + p_amount_sent
    WHERE user_id = p_receiver_id;

    INSERT INTO points_transactions (sender_id, receiver_id, amount_sent)
    VALUES
    (p_sender_id, p_receiver_id, p_amount_sent);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE make_gifts_transactions(p_sender_id INT, p_receiver_id INT, p_gift_type gifts)
AS $$
DECLARE
p_gift_price DECIMAL(7,2);
p_sender_balance DECIMAL(8,2);
p_valid_gift gifts;
BEGIN

    p_valid_gift := (SELECT type FROM gift_inventory WHERE type = p_gift_type);

    IF p_valid_gift IS NULL THEN
        RAISE EXCEPTION 'no such gift';
    END IF;

    p_sender_balance := (SELECT balance FROM points_balance WHERE user_id = p_sender_id FOR UPDATE);

    IF p_sender_balance IS NULL THEN
        RAISE EXCEPTION 'no balance added, hence no transactions must take place, fair as all things must be. period.';
    END IF;

    p_gift_price := (SELECT price FROM gift_inventory WHERE type = p_gift_type);

    IF p_sender_balance <= 0 OR p_sender_balance < p_gift_price THEN
    -- Dev Note: nya ichi ni saaan nia arigato in pokimane style mwah mwah (RIP)
        RAISE EXCEPTION 'not enough balance';
    END IF;


    UPDATE points_balance
    SET balance = balance - p_gift_price
    WHERE user_id = p_sender_id;

    INSERT INTO gifts_transactions
    (sender_id, receiver_id, gift_type)
    VALUES (p_sender_id, p_receiver_id, p_gift_type);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION find_deleted_message(
f_message_id INT,
f_deleter_id INT,
f_server_id INT,
OUT o_deleted_of_id INT
)
AS $$
DECLARE
    f_role_check role_name;
    f_deleted_of_id INT;
BEGIN
    f_role_check := (SELECT roles.name FROM roles JOIN
                    users_in_servers ON roles.id = users_in_servers.role_id
                    WHERE users_in_servers.user_id = f_deleter_id
                    AND users_in_servers.server_id = f_server_id
                    );

    f_deleted_of_id := (SELECT user_id FROM messages_in_servers WHERE id = f_message_id);

    IF f_role_check = 'Muted' THEN
            RAISE EXCEPTION 'muted';
    ELSEIF f_role_check =  'Member' AND f_deleter_id <> f_deleted_of_id THEN
            RAISE EXCEPTION 'cant delete';
    END IF;
    o_deleted_of_id := f_deleted_of_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE delete_messages(p_message_id INT, p_deleter_id INT, p_server_id INT)
AS $$
DECLARE
    p_deleted_of_id INT;
BEGIN
    SELECT o_deleted_of_id INTO p_deleted_of_id
    FROM find_deleted_message(p_message_id, p_deleter_id, p_server_id);

    UPDATE messages_in_servers
    SET is_deleted = TRUE
    WHERE id = p_message_id;

    INSERT INTO audit_logs
    (deleted_of_id, deleted_by_id, message_id, server_id)
    VALUES
    (p_deleted_of_id, p_deleter_id, p_message_id, p_server_id);

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION "show_audit_logs"(f_server_id INT)
RETURNS TABLE(
victim VARCHAR(24),
deleter VARCHAR(24),
message_deleted VARCHAR(2000)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
    victim.username AS "vic",
    deleter.username AS "del",
    messages_in_servers.message
    FROM audit_logs
    JOIN messages_in_servers
        ON audit_logs.message_id = messages_in_servers.id
    JOIN users AS deleter
        ON audit_logs.deleted_by_id = deleter.id
    JOIN users AS victim
        ON audit_logs.deleted_of_id = victim.id
    WHERE messages_in_servers.server_id = f_server_id
;
END;
$$ LANGUAGE plpgsql;


-- Learned: Procedures maintain scope. Don't return inputs.
-- Previously i was returning the same inputs to outputs without any change
-- That was a problem because the arguments that already were passed into the main procedure,
-- I was just getting them back again for no reason, which was an issue, so I fixed that.

CREATE VIEW "p_t_logs" AS
SELECT
    senders.username AS sender,
    receivers.username AS receiver,
    points_transactions.amount_sent
FROM
    points_transactions
JOIN users AS senders
    ON senders.id = points_transactions.sender_id
JOIN users AS receivers
    ON receivers.id = points_transactions.receiver_id
;

CREATE VIEW "g_t_logs" AS
SELECT
    senders.username AS sender,
    receivers.username AS receiver,
    gifts_transactions.gift_type
FROM
    gifts_transactions
JOIN users AS senders
    ON senders.id = gifts_transactions.sender_id
JOIN users AS receivers
    ON receivers.id = gifts_transactions.receiver_id
;

CREATE VIEW view_user_balance AS
SELECT users.username, points_balance.balance
FROM points_balance JOIN users
ON points_balance.user_id = users.id;
-- CREATE OR REPLACE FUNCTION user_gifts_transactions_logs(
-- f_user_id INT)
-- RETURNS TABLE(
-- sender_name VARCHAR(24),
-- receiver_name VARCHAR(24),
-- gift_type gifts,
-- gift_price DECIMAL(5,2)
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--     (SELECT username FROM users WHERE id = f_user_id) AS "sender_name",
--     users.username,
--     gifts_transactions.gift_type, gift_inventory.price
--     FROM gifts_transactions
--     JOIN users ON users.id =
--     gifts_transactions.receiver_id
--     JOIN gift_inventory ON gift_inventory.gift_type
--     = gifts_transactions.gift_type
--     WHERE gifts_transactions.sender_id = f_user_id;
-- END;
-- $$ LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION user_points_transactions_logs(
-- f_user_id INT)
-- RETURNS TABLE(
--     sender_name VARCHAR(24),
--     receiever_name VARCHAR(24),
--     amount_sent DECIMAL(8,2)
-- ) AS $$
-- BEGIN
--     RETURN QUERY
--     SELECT
--     (SELECT username FROM users WHERE id = f_user_id) AS "sender_name",
--     users.username, points_transactions.amount_sent
--     FROM points_transactions JOIN users
--     ON users.id = points_transactions.receiver_id
--     WHERE sender_id = f_user_id;
-- END;
-- $$ LANGUAGE plpgsql;

CREATE VIEW custom_sm AS
SELECT users.id AS user_id, users.username, servers.server_name,
messages_in_servers.message, messages_in_servers.attachment, messages_in_servers.sent_at
FROM messages_in_servers
JOIN users
    ON users.id = messages_in_servers.user_id
JOIN servers
    ON servers.id = messages_in_servers.server_id
WHERE messages_in_servers.is_deleted = FALSE;

CREATE INDEX "users_index" ON "users"("id","username","verified");

CREATE INDEX "servers_index" ON "servers"("id", "server_name", "security_level");

CREATE INDEX "users_in_servers_index" ON "users_in_servers"("user_id", "server_id", "role_id");

CREATE INDEX "points_balance_index" ON "points_balance"("user_id", "balance");
CREATE INDEX "points_transactions_index" ON "points_transactions"("sender_id", "receiver_id", "amount_sent");
CREATE INDEX "gifts_transactions_index" ON "gifts_transactions"("sender_id", "receiver_id", "gift_type"); -- added cus gift type is an enum only

CREATE INDEX "messages_in_servers_index" ON "messages_in_servers"("id", "user_id", "server_id", "is_deleted", "sent_at");

CREATE INDEX "audit_log_index" ON "audit_logs"("message_id", "deleted_of_id", "deleted_by_id", "server_id");
