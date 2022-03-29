create table if not exists sellings (
	car_id VARCHAR(50) references cars(id),
	customer_id INT references customers(id),
	employee_id VARCHAR(50) references employees(id),
	selldate DATE
);
insert into sellings (car_id, customer_id, employee_id, selldate) values ('6676312514', 9, '08-8304992', '8/20/2010');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('6845489157', 7, '04-3978099', '2/28/2000');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('6361552004', 5, '04-3978099', '4/5/2001');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('4364177768', 4, '08-8304992', '4/20/2008');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('4210434116', 3, '31-6990059', '1/25/2002');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('9569308974', 6, '25-0814748', '5/18/2016');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('1973450283', 2, '08-8304992', '6/26/2012');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('4353456962', 8, '31-6990059', '10/3/2020');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('4661247132', 1, '31-6990059', '6/9/2012');
insert into sellings (car_id, customer_id, employee_id, selldate) values ('7298252046', 10, '25-0814748', '11/22/2007');
