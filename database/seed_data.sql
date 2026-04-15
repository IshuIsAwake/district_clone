-- Zomato District clone - sample data
USE zomato_district;

-- ------------------------------------------------------------
-- Event_Category
-- ------------------------------------------------------------
INSERT INTO Event_Category (category_name, description) VALUES
('Live Music',    'Concerts, gigs and acoustic sets across genres.'),
('Comedy',        'Stand-up, improv and open mic nights.'),
('DJ Night',      'Club nights, festival stages and electronic showcases.'),
('Food Festival', 'Street food fairs and curated culinary events.'),
('Workshop',      'Hands-on sessions and masterclasses.'),
('Theatre',       'Plays, musicals and stage performances.'),
('Sports',        'Live sports viewings and tournaments.');

-- ------------------------------------------------------------
-- Location
-- ------------------------------------------------------------
INSERT INTO Location (venue_name, city, state, locality, pin_code, max_event_capacity) VALUES
('Jawaharlal Nehru Stadium',   'Delhi',     'Delhi',       'Lodhi Road',   '110003', 5000),
('NSCI Dome',                  'Mumbai',    'Maharashtra', 'Worli',        '400018', 4000),
('Phoenix Marketcity',         'Bangalore', 'Karnataka',   'Whitefield',   '560066', 2500),
('Kingdom of Dreams',          'Gurugram',  'Haryana',     'Sector 29',    '122002', 1500),
('Bangalore Palace Grounds',   'Bangalore', 'Karnataka',   'Palace Road',  '560052', 8000),
('Famous Studios',             'Mumbai',    'Maharashtra', 'Mahalaxmi',    '400011', 800),
('Indira Gandhi Indoor Stadium','Delhi',    'Delhi',       'ITO',          '110002', 4500);

-- ------------------------------------------------------------
-- Host
-- ------------------------------------------------------------
INSERT INTO Host (host_name, contact_email, contact_number) VALUES
('BookMyShow Live',       'live@bms.in',            '9876501234'),
('Sunburn Events',        'contact@sunburn.in',     '9876501235'),
('District Comedy Co',    'hello@districtcomedy.in','9876501236'),
('Bacardi NH7 Weekender', 'nh7@bacardi.in',         '9876501237'),
('Paytm Insider',         'ops@insider.in',         '9876501238');

-- ------------------------------------------------------------
-- User
-- ------------------------------------------------------------
INSERT INTO User (name, phone_number, email, gender, dob, marital_status, anniversary_date, occupation, city) VALUES
('Aarav Sharma',  '9812345601', 'aarav.sharma@gmail.com',  'Male',   '1998-05-14', 'Single',  NULL,         'Software Engineer', 'Delhi'),
('Isha Patel',    '9812345602', 'isha.patel@gmail.com',    'Female', '1996-08-22', 'Married', '2022-02-14', 'Product Manager',   'Mumbai'),
('Rohan Verma',   '9812345603', 'rohan.verma@gmail.com',   'Male',   '2000-11-03', 'Single',  NULL,         'Student',           'Bangalore'),
('Priya Nair',    '9812345604', 'priya.nair@outlook.com',  'Female', '1995-03-27', 'Single',  NULL,         'Designer',          'Bangalore'),
('Kabir Singh',   '9812345605', 'kabir.singh@gmail.com',   'Male',   '1990-07-09', 'Married', '2019-12-05', 'Architect',         'Delhi'),
('Ananya Iyer',   '9812345606', 'ananya.iyer@gmail.com',   'Female', '1999-01-18', 'Single',  NULL,         'Data Analyst',      'Mumbai'),
('Vikram Rao',    '9812345607', 'vikram.rao@yahoo.com',    'Male',   '1988-06-30', 'Married', '2016-11-20', 'Consultant',        'Gurugram'),
('Meera Kapoor',  '9812345608', 'meera.kapoor@gmail.com',  'Female', '2001-09-12', 'Single',  NULL,         'Student',           'Delhi'),
('Arjun Menon',   '9812345609', 'arjun.menon@gmail.com',   'Male',   '1994-12-02', 'Single',  NULL,         'Photographer',      'Bangalore'),
('Sneha Reddy',   '9812345610', 'sneha.reddy@gmail.com',   'Female', '1997-04-25', 'Single',  NULL,         'Marketer',          'Mumbai');

-- ------------------------------------------------------------
-- Performer
-- ------------------------------------------------------------
INSERT INTO Performer (name, performer_type) VALUES
('Prateek Kuhad',      'Singer'),
('Zakir Khan',         'Comedian'),
('Nucleya',            'DJ'),
('The Local Train',    'Band'),
('Kanan Gill',         'Comedian'),
('Ritviz',             'DJ'),
('Parvaaz',            'Band'),
('Biswa Kalyan Rath',  'Comedian');

-- ------------------------------------------------------------
-- Offer
-- ------------------------------------------------------------
INSERT INTO Offer (code, type, discount_value, start_date, end_date, is_active) VALUES
('FIRST50',   'percentage', 50.00, '2026-01-01', '2026-12-31', TRUE),
('EARLYBIRD', 'percentage', 20.00, '2026-03-01', '2026-06-30', TRUE),
('ZOMATO10',  'percentage', 10.00, '2026-01-01', '2026-12-31', TRUE),
('GROUP25',   'percentage', 25.00, '2026-04-01', '2026-07-31', TRUE),
('WEEKEND15', 'flat',       150.00,'2026-04-01', '2026-05-31', TRUE);

-- ------------------------------------------------------------
-- Event
-- seats_available here is the INITIAL stock for each event.
-- We intentionally do NOT decrement it for the seeded bookings so that
-- fn_seats_remaining() can demonstrate dynamic computation against the
-- stored "live" value - good viva talking point on stored vs. derived.
-- ------------------------------------------------------------
INSERT INTO Event (title, event_date, start_time, duration, age_limit, seats_available, price, description, category_id, location_id, host_id) VALUES
('Prateek Kuhad Live',            '2026-05-10', '19:30:00', 120, 12,  450, 1999.00, 'An intimate evening of indie folk with chart-topping singer-songwriter Prateek Kuhad.', 1, 1, 1),
('Zakir Khan: Mann Pasand',       '2026-05-22', '20:00:00',  90, 15,  200, 1499.00, 'Sakht launda turns storyteller in his most personal set yet.',                         2, 2, 3),
('Sunburn Arena ft. Nucleya',     '2026-06-05', '21:00:00', 180, 18,  300, 2499.00, 'Basslines, beats and the unmistakable Nucleya bounce in a high-energy club night.',    3, 3, 2),
('Bangalore Street Food Fest',    '2026-05-15', '12:00:00', 480,  0,  500,  299.00, 'Over 60 stalls curated from across the country. Live music stage, kid-friendly.',      4, 5, 5),
('The Local Train Unplugged',     '2026-06-12', '19:00:00', 150, 14,  250, 1299.00, 'The band strips down their biggest hits in an acoustic-only set.',                      1, 6, 1),
('Kanan Gill: New Material',      '2026-04-28', '20:30:00',  75, 18,  180,  999.00, 'Work-in-progress night: first public outing of brand new jokes.',                       2, 4, 3),
('Bacardi NH7 Weekender Delhi',   '2026-07-18', '16:00:00', 600, 18, 2000, 3499.00, 'The happiest music festival in India returns with a three-stage Delhi edition.',       1, 7, 4),
('Ritviz Live',                   '2026-03-20', '20:00:00', 150, 16,  250, 1799.00, 'Liggi, Udd Gaye and more - an electronic set you can actually dance to.',               3, 3, 2),
('Biswa Stand-up Special',        '2026-03-05', '19:30:00',  90, 15,  180,  899.00, 'Biswa Kalyan Rath takes apart everyday life with signature deadpan delivery.',         2, 6, 3),
('Parvaaz Live Acoustic',         '2026-02-14', '18:30:00', 120,  0,  150, 1099.00, 'Bangalore psychedelic rock outfit in a rare Delhi acoustic performance.',               1, 4, 1);

-- ------------------------------------------------------------
-- Booking
-- ------------------------------------------------------------
INSERT INTO Booking (user_id, event_id, number_of_people, total_price, booking_date, status) VALUES
( 1,  1, 2,  3198.00, '2026-04-01', 'confirmed'),  -- 1 - 20% EARLYBIRD applied
( 2,  2, 3,  4497.00, '2026-04-05', 'confirmed'),  -- 2
( 3,  3, 4,  7497.00, '2026-04-02', 'confirmed'),  -- 3 - 25% GROUP25
( 1,  3, 1,  2499.00, '2026-04-10', 'confirmed'),  -- 4
( 4,  4, 2,   448.00, '2026-04-08', 'confirmed'),  -- 5 - WEEKEND15 flat 150
( 5,  5, 2,  2598.00, '2026-04-03', 'confirmed'),  -- 6
( 2,  7, 4, 10497.00, '2026-04-11', 'confirmed'),  -- 7 - 25% GROUP25
( 6,  2, 2,  2998.00, '2026-04-06', 'cancelled'),  -- 8
( 7,  6, 2,  1998.00, '2026-04-07', 'confirmed'),  -- 9
( 8, 10, 1,  1099.00, '2026-02-10', 'confirmed'),  -- 10
( 9,  8, 2,  3598.00, '2026-03-15', 'confirmed'),  -- 11
(10,  9, 1,   899.00, '2026-03-01', 'confirmed'),  -- 12
( 3,  1, 2,  3598.00, '2026-04-12', 'confirmed'),  -- 13 - 10% ZOMATO10
( 6,  5, 1,  1299.00, '2026-04-09', 'confirmed'),  -- 14
( 4, 10, 2,  2198.00, '2026-02-05', 'confirmed'),  -- 15
( 5,  9, 2,  1798.00, '2026-02-28', 'confirmed'); -- 16

-- ------------------------------------------------------------
-- Transaction (1:1 with Booking)
-- ------------------------------------------------------------
INSERT INTO Transaction (booking_id, payment_method, amount, payment_status, transaction_date) VALUES
( 1, 'UPI',          3198.00, 'completed', '2026-04-01 14:22:10'),
( 2, 'credit_card',  4497.00, 'completed', '2026-04-05 10:05:44'),
( 3, 'UPI',          7497.00, 'completed', '2026-04-02 18:30:12'),
( 4, 'debit_card',   2499.00, 'completed', '2026-04-10 21:17:03'),
( 5, 'wallet',        448.00, 'completed', '2026-04-08 09:47:51'),
( 6, 'UPI',          2598.00, 'completed', '2026-04-03 16:10:29'),
( 7, 'credit_card', 10497.00, 'completed', '2026-04-11 12:02:08'),
( 8, 'net_banking',  2998.00, 'refunded',  '2026-04-06 19:40:55'),
( 9, 'UPI',          1998.00, 'completed', '2026-04-07 11:28:14'),
(10, 'UPI',          1099.00, 'completed', '2026-02-10 20:55:41'),
(11, 'credit_card',  3598.00, 'completed', '2026-03-15 08:33:22'),
(12, 'wallet',        899.00, 'completed', '2026-03-01 17:09:06'),
(13, 'UPI',          3598.00, 'completed', '2026-04-12 22:11:47'),
(14, 'debit_card',   1299.00, 'completed', '2026-04-09 15:48:30'),
(15, 'UPI',          2198.00, 'completed', '2026-02-05 13:25:18'),
(16, 'UPI',          1798.00, 'completed', '2026-02-28 19:12:09');

-- ------------------------------------------------------------
-- Review (only on past events: 8, 9, 10)
-- ------------------------------------------------------------
INSERT INTO Review (user_id, event_id, rating, comment, review_date) VALUES
(10, 9,  5, 'Hilarious set, laughed till my sides hurt. Worth every rupee.',        '2026-03-06'),
( 9, 8,  4, 'Incredible energy, wish the sound mix was a touch cleaner.',          '2026-03-21'),
( 8, 10, 5, 'Magical night. Parvaaz was soul-stirring in that small room.',         '2026-02-15'),
( 4, 10, 4, 'Beautiful acoustics, the intimate venue really made it special.',      '2026-02-15'),
( 5, 9,  3, 'Decent show but felt a bit overrated for the ticket price.',           '2026-03-01');

-- ------------------------------------------------------------
-- Saved_Item
-- ------------------------------------------------------------
INSERT INTO Saved_Item (user_id, event_id, saved_date) VALUES
(1, 2, '2026-03-28'),
(1, 7, '2026-04-02'),
(2, 3, '2026-03-30'),
(3, 5, '2026-04-01'),
(4, 1, '2026-04-04'),
(5, 7, '2026-04-08'),
(6, 4, '2026-04-09'),
(8, 6, '2026-04-11');

-- ------------------------------------------------------------
-- Event_Performer
-- ------------------------------------------------------------
INSERT INTO Event_Performer (event_id, performer_id, performance_order) VALUES
( 1, 1, 1),  -- Prateek Kuhad Live
( 2, 2, 1),  -- Zakir Khan
( 3, 3, 1),  -- Sunburn ft. Nucleya
( 5, 4, 1),  -- The Local Train
( 6, 5, 1),  -- Kanan Gill
( 7, 1, 2),  -- NH7: Prateek Kuhad (headliner slot 2)
( 7, 4, 1),  -- NH7: The Local Train (opener)
( 7, 7, 3),  -- NH7: Parvaaz
( 8, 6, 1),  -- Ritviz
( 9, 8, 1),  -- Biswa
(10, 7, 1);  -- Parvaaz

-- ------------------------------------------------------------
-- Booking_Offer
-- ------------------------------------------------------------
INSERT INTO Booking_Offer (booking_id, offer_id, discount_applied) VALUES
( 1, 2,  800.00),   -- EARLYBIRD 20% on 3998
( 3, 4, 2499.00),   -- GROUP25 on 9996
( 5, 5,  150.00),   -- WEEKEND15 flat
( 7, 4, 3499.00),   -- GROUP25 on 13996
(13, 3,  400.00);   -- ZOMATO10 on 3998
