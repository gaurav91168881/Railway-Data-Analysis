Create Database railway_analysis;

Use railway_analysis;

CREATE TABLE railway_data (
    Transaction_ID VARCHAR(50),
    Date_of_Purchase DATE,
    Time_of_Purchase TIME,
    Purchase_Type VARCHAR(20),
    Payment_Method VARCHAR(30),
    Railcard VARCHAR(20),
    Ticket_Class VARCHAR(20),
    Ticket_Type VARCHAR(20),
    Price DECIMAL(10,2),
    Departure_Station VARCHAR(100),
    Arrival_Destination VARCHAR(100),
    Date_of_Journey DATE,
    Departure_Time TIME,
    Arrival_Time TIME,
    Actual_Arrival_Time TIME,
    Journey_Status VARCHAR(20),
    Reason_for_Delay VARCHAR(50),
    Refund_Request VARCHAR(10)
);

-- show tables;
-- describe railway_data;

SHOW VARIABLES LIKE 'local_infile';

SELECT COUNT(*) AS total_rows
FROM railway_data;
USE railway_analysis;


LOAD DATA LOCAL INFILE 'C:/Users/Gaurav/Downloads/railway_dataset.csv'
INTO TABLE railway_data
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    Transaction_ID,
    @Date_of_Purchase,
    @Time_of_Purchase,
    Purchase_Type,
    Payment_Method,
    Railcard,
    Ticket_Class,
    Ticket_Type,
    Price,
    Departure_Station,
    Arrival_Destination,
    @Date_of_Journey,
    @Departure_Time,
    @Arrival_Time,
    @Actual_Arrival_Time,
    Journey_Status,
    Reason_for_Delay,
    Refund_Request
)
SET
    Date_of_Purchase = STR_TO_DATE(@Date_of_Purchase, '%Y-%m-%d'),
    Time_of_Purchase = NULLIF(@Time_of_Purchase, ''),
    Date_of_Journey = STR_TO_DATE(@Date_of_Journey, '%Y-%m-%d'),
    Departure_Time = NULLIF(@Departure_Time, ''),
    Arrival_Time = NULLIF(@Arrival_Time, ''),
    Actual_Arrival_Time = NULLIF(@Actual_Arrival_Time, '');
    
SELECT COUNT(*) AS total_rows    
FROM railway_data;

select * from railway_data limit 10;


SELECT
    COUNT(*) AS total_rows,
    MIN(Date_of_Purchase) AS first_purchase,
    MAX(Date_of_Purchase) AS last_purchase,
    MIN(Date_of_Journey) AS first_journey,
    MAX(Date_of_Journey) AS last_journey
FROM railway_data;


-- Count of Journey by status: 
SELECT
    Journey_Status,
    COUNT(*) AS total_journeys
FROM railway_data
GROUP BY Journey_Status
ORDER BY total_journeys DESC;


-- Checking the missing values- 
SELECT
    SUM(Transaction_ID IS NULL) AS missing_transaction_ids,
    SUM(Date_of_Purchase IS NULL) AS missing_purchase_dates,
    SUM(Date_of_Journey IS NULL) AS missing_journey_dates,
    SUM(Price IS NULL) AS missing_prices,
    SUM(Departure_Station IS NULL) AS missing_departure_stations,
    SUM(Arrival_Destination IS NULL) AS missing_destinations
FROM railway_data;


### Identify Peak Purchase Times and Their Impact on Delays:
-- Objective: Identify peak ticket-purchasing hours and analyze the relationship between ticket purchase times and 
-- 			  journey delays to understand purchasing patterns and potential delay trends.

SELECT
    HOUR(Time_of_Purchase) AS purchase_hour,
    COUNT(*) AS total_journeys,
    SUM(Journey_Status = 'Delayed') AS delayed_journeys,
    ROUND(100.0 * SUM(Journey_Status = 'Delayed') / COUNT(*), 2) AS delay_percentage
FROM railway_data
WHERE Journey_Status IN ('On Time', 'Delayed')
GROUP BY HOUR(Time_of_Purchase)
ORDER BY delay_percentage DESC;

-- Key findings >>
-- The highest number of ticket purchases occurred between 5 PM and 6 PM, with 2,740 transactions.
-- The highest delay rate was observed for tickets purchased between 9 AM and 10 AM, at 23.77%.
-- The 5 PM purchase hour had a delay rate of 7.46% among non-cancelled journeys.
-- The results show that the busiest purchase period did not have the highest delay rate.


### Analyze Journey Patterns of Frequent Travelers:
-- Objective: Identify frequent travelers (those who made more than three purchases) and analyze their most common journey patterns.

-- Here the dataset has no customer ID or passenger ID, so we cannot identify repeat purchases by the same traveler. 
-- So here the analysis for most popular journey route. 

SELECT
    Departure_Station,
    Arrival_Destination,
    COUNT(*) AS total_journeys
FROM railway_data
GROUP BY
    Departure_Station,
    Arrival_Destination
ORDER BY total_journeys DESC
LIMIT 10;

-- Key findings >>
-- Most-used route: Manchester Piccadilly to Liverpool Lime Street with 4,628 journeys.
-- Second most-used route: London Euston to Birmingham New Street with 4,209 journeys.


### Revenue Loss Due to Delays with Refund Requests: 
-- Objective: Calculate the total revenue loss due to delayed journeys for which a refund request was made.

SELECT
    COUNT(*) AS delayed_refund_requests,
    ROUND(SUM(Price), 2) AS revenue_loss
FROM railway_data
WHERE Journey_Status = 'Delayed'
  AND Refund_Request = 'Yes';
  
-- Key finding >>
-- this identified that 546 delayed journeys for which the passengers requested refunds and the total revenue loss was 26165. 

-- >> here, the revenue loss according to the reason for delays for which refund requested 
SELECT
    Reason_for_Delay,
    COUNT(*) AS refund_requests,
    ROUND(SUM(Price), 2) AS revenue_loss
FROM railway_data
WHERE Journey_Status = 'Delayed'
  AND Refund_Request = 'Yes'
GROUP BY Reason_for_Delay
ORDER BY revenue_loss DESC;


### Impact of Railcards on Ticket Prices and Journey Delays:
-- Objective: Analyze the average ticket price and delay rate for journeys purchased with and without railcards.

SELECT
    CASE
        WHEN Railcard = 'None' THEN 'Without Railcard'
        ELSE 'With Railcard'
    END AS railcard_status,
    COUNT(*) AS total_journeys,
    ROUND(AVG(Price), 2) AS average_ticket_price,
    SUM(Journey_Status = 'Delayed') AS delayed_journeys,
    ROUND(100.0 * SUM(Journey_Status = 'Delayed') / NULLIF(SUM(Journey_Status IN ('On Time', 'Delayed')), 0), 2) AS delay_rate
FROM railway_data
GROUP BY
    CASE
        WHEN Railcard = 'None' THEN 'Without Railcard'
        ELSE 'With Railcard'
    END
ORDER BY railcard_status;

-- Key finding >>
-- The average ticket price for journeys with railcards -> 15.67 and for journeys without railcards -> 27.43
-- Delay rate for journeys with railcards -> 8.71% compared with journeys without railcards --> 7.18%
-- The dataset contained 10,735 journeys with railcards and 20,918 journeys without railcards


### Journey Performance by Departure and Arrival Stations
-- Objective: Evaluate journey performance by calculating the average delay time for each pair of departure and arrival stations.

SELECT
    Departure_Station,
    Arrival_Destination,
    COUNT(*) AS delayed_journeys,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)), 2) AS average_delay_time_min
FROM railway_data
WHERE Journey_Status = 'Delayed'
GROUP BY
    Departure_Station,
    Arrival_Destination
ORDER BY average_delay_time_min DESC;

-- Key finding >>
-- Highest Average delay -> Manchester Piccadilly to Leeds is 143.73 min across 64 delayed journeys
-- Liverpool Lime Street to London Euston recorded the largest visible number of delayed journeys, at 780, with an average delay of 36.58 minutes.
  












