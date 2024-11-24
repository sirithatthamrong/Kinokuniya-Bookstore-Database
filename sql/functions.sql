CREATE EXTENSION IF NOT EXISTS pgcrypto; -- For crypt() and gen_salt() function


/****************************************************************************************
CREATE CUSTOMER FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION create_customer(
    p_username VARCHAR,
    p_password VARCHAR,
    p_first_name VARCHAR,
    p_last_name VARCHAR
) RETURNS VOID AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM customer WHERE customer.username = p_username) THEN
        RAISE EXCEPTION 'Username already exists.';
    ELSE
        INSERT INTO customer (username, password, first_name, last_name, membership_type) VALUES (p_username, crypt(p_password, gen_salt('bf')), p_first_name, p_last_name, 'Regular'); -- Default membership
    END IF;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
VERIFY CUSTOMER FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION  verify_customer(
    p_username character varying,
    p_password character varying
) RETURNS BOOLEAN AS $$
DECLARE
    stored_password TEXT; -- Variable to hold the hashed password from the database
BEGIN
    -- Retrieve the hashed password for the given username
    SELECT password INTO stored_password
    FROM customer
    WHERE customer.username = p_username;

    -- If no matching username is found, return FALSE
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Compare the provided password with the stored hashed password
    IF stored_password = crypt(p_password, stored_password) THEN
        RETURN TRUE; -- Password is correct
    ELSE
        RETURN FALSE; -- Password is incorrect
    END IF;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
UPDATE CUSTOMER FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION update_customer(
    p_username VARCHAR,
    p_first_name VARCHAR,
    p_middle_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_phone_number VARCHAR,
    p_address TEXT,
    p_date_of_birth DATE,
    p_membership_type VARCHAR
) RETURNS VOID AS $$
BEGIN
    UPDATE customer
    SET first_name = p_first_name,
        middle_name = p_middle_name,
        last_name = p_last_name,
        email = p_email,
        phone_number = p_phone_number,
        address = p_address,
        date_of_birth = p_date_of_birth,
        membership_type = p_membership_type
    WHERE username = p_username;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
GET CUSTOMER DETAILS FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION get_membership_details(p_username VARCHAR)
    RETURNS TABLE (
                      loyalty_points INTEGER,
                      discount_rate NUMERIC,
                      membership_status VARCHAR,
                      shipping_discount NUMERIC,
                      free_shipping BOOLEAN
                  ) AS $$
BEGIN
    RETURN QUERY
        SELECT c.loyalty_points,
               COALESCE(s.discount_rate, g.discount_rate, p.discount_rate, 0) AS discount_rate,
               c.membership_type AS membership_status,
               COALESCE(g.shipping_discount, 0) AS shipping_discount,
               COALESCE(p.free_shipping, FALSE) AS free_shipping
        FROM customer c
                 LEFT JOIN Silver s ON c.customer_id = s.customer_id
                 LEFT JOIN Gold g ON c.customer_id = g.customer_id
                 LEFT JOIN Platinum p ON c.customer_id = p.customer_id
        WHERE c.username = p_username;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
ADD OR UPDATE REVIEW FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION add_or_update_review(
    p_customer_id INTEGER,
    p_book_id INTEGER,
    p_rating INTEGER,
    p_review_text TEXT
) RETURNS VOID AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM review WHERE customer_id = p_customer_id AND book_id = p_book_id) THEN
        -- Update existing review
        UPDATE review
        SET rating = p_rating,
            review_text = p_review_text,
            review_date = CURRENT_TIMESTAMP
        WHERE customer_id = p_customer_id AND book_id = p_book_id;
    ELSE
        -- Insert new review
        INSERT INTO review (customer_id, book_id, rating, review_text, review_date)
        VALUES (p_customer_id, p_book_id, p_rating, p_review_text, CURRENT_TIMESTAMP);
    END IF;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
ADD BOOK TO WISHLIST FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION add_book_to_wishlist(
    p_customer_id INTEGER,
    p_book_id INTEGER
) RETURNS VOID AS $$
BEGIN
    INSERT INTO wishlist (customer_id, book_id)
    VALUES (p_customer_id, p_book_id);
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
REMOVE BOOK FROM WISHLIST FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION remove_book_from_wishlist(
    p_customer_id INTEGER,
    p_book_id INTEGER
) RETURNS VOID AS $$
BEGIN
    DELETE FROM wishlist
    WHERE customer_id = p_customer_id AND book_id = p_book_id;
END;
$$ LANGUAGE plpgsql;


/****************************************************************************************
GET CUSTOMER WISHLIST FUNCTION
*****************************************************************************************/
CREATE OR REPLACE FUNCTION get_customer_wishlist(p_username VARCHAR)
RETURNS TABLE (
    book_id INTEGER,
    title VARCHAR,
    author VARCHAR,
    genre VARCHAR,
    price MONEY
) AS $$
BEGIN
    RETURN QUERY
    SELECT b.book_id, b.title, b.author, b.genre, b.price
    FROM wishlist w
    JOIN book b ON w.book_id = b.book_id
    WHERE w.customer_id = (SELECT customer_id FROM customer WHERE username = p_username);
END;
$$ LANGUAGE plpgsql;