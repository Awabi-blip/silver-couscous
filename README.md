# Design Document

By Muhammad Awab

Video overview: <https://youtu.be/xsSlE-J1fzU>

A chat application database with virtual economy system

## Scope

The purpose of this database is to provide a rigid backend database for a chat application
where users can make transactions with other users aswell.

The scope of data base includes people, servers, roles and permissions in respective servers, messages, friendship relationships, gifts, points, transactions for gifts and points.

The things that are outside the scope of this database are custom roles, channels, channels
permissions overrides, storage of credit card numbers and real banking transactions,
reply messages, threads within channels. These features exist in a database such as
discord or slack.

## Functional Requirements

A user can make a profile, add verification to it, upload their pfps (which are stored as paths to the pictures in a server not the raw jpeg itself), set display names,create servers, join servers, add descriptions and pfps and display names to servers, add friends, make transactions for points or gifts and send messagesin servers.

The database is limited in ways that, user can not upload images for their pfps rather specify a path for it, or send videos or voice data, create roles on their own, and they have to work with pre specified roles, can not retrieve a history of "version protocol" of messages i.e access their previous uneditted states, and so forth. Users can also not link real credit card numbers or deposit actual cash.

## Representation

### Entities

The database has entities such as : USERS, SERVERS, ROLES, MESSAGES_IN_SERVERS, MESSAGES_IN_DMS, GIFTS_INVENTORY, POINTS_BALANCE, FRIENDS, AUDIT_LOGS.

#### Attributes for each entity involves :

**USERS**
- id: Unique identifier (Primary Key).
- username, display_name: Identity fields.
- badge: Custom Enum (e.g., 'The Architect', 'Void Cat') to represent neurodivergent traits.
- status: Custom Enum for current state (e.g., 'Sensory Overload').
- pfp: Path to profile picture.
- verified: Boolean flag for security checks.

**Servers**
- id: Unique identifier.
- server_name: Unique internal name.
- security_level: Enum ('Level 1', 'Level 2') for determining entry requirements.
- banner, icon: Visual assets.

**Roles**
- id: Unique identifier.
- name: Enum ('Member', 'Admin', 'Muted').
- permissions: Array of text strings defining what the role can do.

**Users_in_Servers (Junction Table)**
- Links user_id and server_id.
- Assigns a role_id to the user in that specific server.

**Messages_in_Servers**
- id: Unique identifier.
- message: The content (max 2000 chars).
- attachment: Path to file (if any).
- is_deleted: Soft delete flag (data remains for audit logs).

**Points_Balance**
- user_id: Links to user.
- balance: Decimal value for the balance that the user has.

**Gift_Inventory**
- type: Enum key for items (e.g., 'weighted blanket').
- price: Cost of the item.

**Transactions** (points_transactions, gifts_transactions)
- Logs sender_id, receiver_id, and amount/gift_type to track the flow of the economy.

**Audit_Logs**
- Tracks deleted messages (message_id) alongside the deleted_by_id and the deleted_of_id (victim) for management system.

#### Types used:

##### All primary key ids used SERIAL for auto-increment.
##### all pictures: storing images within the database would make it extremely heavy and slow, and considering that, a user can upload an image which can be stored in a folder, and it's path can be referenced within the database.

###### USERS
- **badge ENUM**: these were predefined badges that the user can add on their profile based on their neurodivergence type, i.e eclipse for BPD, or vanilla latte for neurotypicals.
- **verfication_status BOOLEAN**: because it can have a binary value of either True or False only.

###### SERVERS
- **security_level ENUM**: altho boolean was okay, going with enum means that in future more levels can be added

###### ROLES
- **permissions TEXT[]**: an array was used to store multiple permissions in the same row for simplicity purposes.
- **The roles table is essentially a lookup table, with the default role given to users upon joining a new server being member with send, delete and view messages permissions**

###### POINTS_BALANCE
- **balance decimal(8,2)**: a good trade off for accuracy and storage, 6 figures should be enough for most transactions.

###### GIFTS_INVENTORY:
- **type ENUM** ENUM for items, i.e weighted blanket
- **price decimal(7,2)** the highest price set for a gift is 3 figures so 5 gives a good stress test and possibilites for more expensive items to be added.

###### MESSAGES:
- **varchar (2000)** 2000 is a good limit for a messages, gives good enough upperbounds to send messages manageable to store.

### Relationships
<img width="1601" height="827" alt="contra_ERD_1" src="https://github.com/user-attachments/assets/ea8ae1b7-b95f-4eb0-8b82-2b7004b3adcb" />


**users** have a many to many relationship with servers as in one user can be in many servers, and more than one server can have the same user. The user must only have one role within the server, as accomplished by the junction table *users_in_servers*, which by default adds the member role to the user upon joining, unless specified otherwise. The **PK** for *users_in_servers* is essentially the *user_id* in composition with the *server_id* as it enforces the rule for one user having only one role within the server. User itself has a many to many relationship with roles, as in one user might have multiple roles, but not within the same server, and similarly the same role i.e member can be shared by multiple users

The **messages_in_servers** table has a many to many relationship with users and a many to manyrelationship with servers. One user can have many messages, and one server can host many messages.The user must be in the server in order to send messages.

The **gifts_inventory** table is a lookup table which has been populated by a bunch of gifts.
It has a one-to-many relationship with the gifts_transactions table as in one gift can appear multiple times in the transaction

The **points_balance** table has a one-to-one relationship with users. One user must only have onw row associated with their balance.

The **points_transactions** table has a one-to-many relationship with users. One user can make multiple transactions, but each transaction must refer to one user only.

The **gifts_transactions** table has a one-to-many relationship with users. One user can make multiple gift_transacitons and each transaction must refer to one user only.

THE **audit_Logs** table has a one-to-many relationship with users as one user can delete or have multiple of their messages deleted, but each log represents one user only. It also has a one-to-many relationship with servers as in one server can have multiple rows that represent it's logged audits. Messages have a one-to-one relationship with audit_logs as one message may and may only be deleted once.

## Optimizations

The **check_user_integrity()** trigger exists to accompany the security check in servers. It runs before insert on users_in_servers, and checks whether a user qualifies to be in that server. If a user has a verified account only then they are allowed to enter servers with security_level 2.

**users_index** uses index on username and verified to quickly get the user and covering index verified to check their verification.

**servers_index** user index on servername and security level to quickly search the server by its name and use covering index for it's security level

**points_balance_index** to search for a specific balance, i.e users with balance more than 3000 quickly.

**points/gifts_transactions_index** to compliment the view get_p_t logs to quickly fetch users and transactions using a covering index on sender_id, receiver_id and the amount_sent/gift sent.

**audit_logs_index** uses a covering index on message_id, deleter_id, deleted_id, server_id to quickly fetch the audit_logs when the get_audit_logs is called. Since the stored datatypes are only ints, I figured it's okay to with a 4 column covering index.

## Limitations

Unsuitable design for HFT, as there is only one table to deal with points_transactions.There is no sharding being performed to split the data across multiple tables to accompany high frequency transactions.

If the messages_in_servers table grows upto ten million or more rows, the inserts would get slower, again an issue due to lack of sharding.

Since the database is not directly storing the images, fetching the images would be a slower task as first the path would be retrieved and then the image from the server using that path.

**The database will not be able to design well around:**
Channels, in servers.
Messages in channels in servers using roles.
Specific Role Permissions and overrides for channels.
Actual banking design using storage of actual debit/cerdit cards.
