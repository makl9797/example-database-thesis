ALTER TABLE cars
ADD COLUMN created_at timestamp with time zone not null default now(),
ADD COLUMN updated_at timestamp with time zone;
ALTER TABLE customers
ADD COLUMN created_at timestamp with time zone not null default now(),
ADD COLUMN updated_at timestamp with time zone;
ALTER TABLE employees
ADD COLUMN created_at timestamp with time zone not null default now(),
ADD COLUMN updated_at timestamp with time zone;
ALTER TABLE sellings 
ADD COLUMN created_at timestamp with time zone not null default now(),
ADD COLUMN updated_at timestamp with time zone;

create table cars_revisions (
    car_id varchar(50) not null references cars(id),
    created_at timestamp with time zone,
    brand VARCHAR(50),
	model VARCHAR(50),
	year VARCHAR(50),
	price VARCHAR(50),
    primary key (car_id, created_at)
);
create table customers_revisions (
    customer_id int not null references customers(id),
    created_at timestamp with time zone,
    first_name VARCHAR(50),
	last_name VARCHAR(50),
	address VARCHAR(50),
    primary key (customer_id, created_at)
);
create table employees_revisions (
    employee_id varchar(50) not null references employees(id),
    created_at timestamp with time zone,
    first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50),
    primary key (employee_id, created_at)
);
create table sellings_revisions (
    car_id varchar(50) not null references cars(id),
	customer_id INT not null references customers(id),
	employee_id VARCHAR(50) not null references employees(id),
	selldate DATE,
    created_at timestamp with time zone,
    primary key (car_id, customer_id, employee_id, created_at)
);

create or replace function trigger_on_cars_revision()
    returns trigger
    language plpgsql as $body$
begin
    if old.brand <> new.brand or old.model <> new.model or old.year <> new.year or old.price <> new.price then
        if old.updated_at is null then
            insert into cars_revisions (car_id, created_at, brand, model, year, price)
            values (old.id, old.created_at, old.brand, old.model, old.year, old.price);
        else
            insert into cars_revisions (car_id, created_at, brand, model, year, price)
            values (old.id, old.updated_at, old.brand, old.model, old.year, old.price);
        end if;
    end if;
    return new;
end; $body$;

create or replace function trigger_on_customers_revision()
    returns trigger
    language plpgsql as $body$
begin
    if old.first_name <> new.first_name or old.last_name <> new.last_name or old.address <> new.address then
        if old.updated_at is null then
            insert into customers_revisions (customer_id, created_at, first_name, last_name, address)
            values (old.id, old.created_at, old.first_name, old.last_name, old.address);
        else
            insert into customers_revisions (customer_id, created_at, first_name, last_name, address)
            values (old.id, old.updated_at, old.first_name, old.last_name, old.address);
        end if;
    end if;
    return new;
end; $body$;

create or replace function trigger_on_employees_revision()
    returns trigger
    language plpgsql as $body$
begin
    if old.first_name <> new.first_name or old.last_name <> new.last_name or old.email <> new.email then
        if old.updated_at is null then
            insert into employees_revisions (employee_id, created_at, first_name, last_name, email)
            values (old.id, old.created_at, old.first_name, old.last_name, old.email);
        else
            insert into employees_revisions (employee_id, created_at, first_name, last_name, email)
            values (old.id, old.updated_at, old.first_name, old.last_name, old.email);
        end if;
    end if;
    return new;
end; $body$;

create or replace function trigger_on_sellings_revision()
    returns trigger
    language plpgsql as $body$
begin
    if old.selldate <> new.selldate then
        if old.updated_at is null then
            insert into sellings_revisions (car_id, customer_id, employee_id, created_at, selldate)
            values (old.car_id, old.customer_id, old.employee_id, old.created_at, old.selldate);
        else
            insert into sellings_revisions (car_id, customer_id, employee_id, created_at, selldate)
            values (old.car_id, old.customer_id, old.employee_id, old.updated_at, old.selldate);
        end if;
    end if;
    return new;
end; $body$;

create trigger trigger_cars_revision
  before update
  on cars
  for each row
execute procedure trigger_on_cars_revision();

create trigger trigger_customers_revision
  before update
  on customers
  for each row
execute procedure trigger_on_customers_revision();

create trigger trigger_employees_revision
  before update
  on employees
  for each row
execute procedure trigger_on_employees_revision();

create trigger trigger_sellings_revision
  before update
  on sellings
  for each row
execute procedure trigger_on_sellings_revision();