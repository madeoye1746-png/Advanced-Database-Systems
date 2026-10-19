-- =====================================================================
-- TripNest — Small, hand-written reference data
-- Run after 01_schema.sql. All data is simulated.
-- =====================================================================
SET search_path TO tripnest;

INSERT INTO country (country_code, country_name) VALUES
 ('NG','Nigeria'), ('GH','Ghana'), ('KE','Kenya'), ('ZA','South Africa'),
 ('GB','United Kingdom'), ('AE','United Arab Emirates'), ('US','United States'), ('FR','France');

INSERT INTO city (city_name, country_code) VALUES
 ('Lagos','NG'), ('Abuja','NG'), ('Port Harcourt','NG'), ('Kano','NG'),
 ('Accra','GH'), ('Nairobi','KE'), ('Johannesburg','ZA'), ('London','GB'),
 ('Dubai','AE'), ('New York','US'), ('Paris','FR');

INSERT INTO airport (iata_code, airport_name, city_id)
SELECT v.iata, v.name, c.city_id
FROM (VALUES
 ('LOS','Murtala Muhammed International','Lagos'),
 ('ABV','Nnamdi Azikiwe International','Abuja'),
 ('PHC','Port Harcourt International','Port Harcourt'),
 ('KAN','Mallam Aminu Kano International','Kano'),
 ('ACC','Kotoka International','Accra'),
 ('NBO','Jomo Kenyatta International','Nairobi'),
 ('JNB','O. R. Tambo International','Johannesburg'),
 ('LHR','London Heathrow','London'),
 ('DXB','Dubai International','Dubai'),
 ('JFK','John F. Kennedy International','New York'),
 ('CDG','Paris Charles de Gaulle','Paris')
) AS v(iata, name, city) JOIN city c ON c.city_name = v.city;

-- Fictional airlines to keep the case study simulated
INSERT INTO airline (airline_code, airline_name) VALUES
 ('TN','TripNest Air'), ('SV','Savanna Airways'), ('AQ','Atlantic Queen'),
 ('HB','Harmattan Blue'), ('NX','NorthStar Express');

INSERT INTO agent (full_name, email, role) VALUES
 ('Adaeze Okafor','adaeze.okafor@tripnest.test','AGENT'),
 ('Tunde Bakare','tunde.bakare@tripnest.test','AGENT'),
 ('Halima Musa','halima.musa@tripnest.test','SUPERVISOR'),
 ('Chidi Nwosu','chidi.nwosu@tripnest.test','ADMIN');
