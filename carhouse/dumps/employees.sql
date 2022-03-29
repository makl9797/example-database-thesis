create table if not exists employees (
	id VARCHAR(50) PRIMARY KEY,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50)
);
insert into employees (id, first_name, last_name, email) values ('08-8304992', 'Dasi', 'Hargitt', 'dhargitt0@wisc.edu');
insert into employees (id, first_name, last_name, email) values ('04-3978099', 'Betty', 'Whitley', 'bwhitley1@yelp.com');
insert into employees (id, first_name, last_name, email) values ('31-6990059', 'Killy', 'Sheraton', 'ksheraton2@npr.org');
insert into employees (id, first_name, last_name, email) values ('25-0814748', 'Nollie', 'Elliman', 'nelliman3@a8.net');
