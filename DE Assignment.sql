
-- Handling the null age 
--Cheks age null handle, date format check, name is clean or not
--found age is NULL for 5 records so mention default not available
--a) Patient-level transformations:
--
--Age group (0-18, 19-30, 31-50, 51-70, 71+)
--Patient type (New: registered < 6 months, Regular: 6-24 months, Long-term: > 24 months)

CREATE TABLE patients_transformed AS
SELECT * , 
CASE 
	WHEN age BETWEEN 0 AND 18 THEN '0-18' 
	WHEN age BETWEEN 19 AND 30 THEN '19-30' 
	WHEN age BETWEEN 31 AND 50 THEN '31-50' 
	WHEN age BETWEEN 51 AND 70 THEN '51-70' 
	WHEN age IS NULL THEN 'Not Available' 
	ELSE '70+' 
END AS age_group,
CASE 
	WHEN registration_date::date >= NOW()::date - INTERVAL '6 months' THEN 'New'
    WHEN registration_date::date >= NOW()::date - INTERVAL '24 months' THEN 'Regular'
    ELSE 'Long-term'
END AS patient_type
FROM patients
;	
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--
--b) Appointment-level transformations:
--
--Day of week (Monday-Sunday)
--Time since last appointment (in days)

-- Cheking column is clean or not

SELECT * FROM appointments;
--
------------------------------------------------------------------------------------------------------------------------------------
--
CREATE TABLE appointments_transformed AS 
SELECT * , to_char(appointment_date::date,'Day') AS day_of_week,
(appointment_date::date -  LAG(appointment_date::date)OVER(PARTITION BY patient_id ORDER BY appointment_date::date)) AS days_since_last_appointment
FROM appointments 
;
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--

-- Prescription-level transformations:
--
--Medication category (e.g., Pain Relief, Diabetes, Heart, etc.)
--Prescription frequency (First-time, Repeat)

CREATE TABLE prescriptions_transformed AS 
SELECT * ,
CASE
	WHEN medication_name = 'Ibuprofen' THEN 'Pain Relief'
	WHEN medication_name = 'Metformin' THEN 'Diabetes'
	WHEN medication_name IN ('Lisinopril', 'Aspirin', 'Atorvastatin') THEN 'Heart'
	WHEN medication_name = 'Amoxicillin' THEN 'Antibiotic'
	ELSE 'Others'
END AS medication_category ,
CASE 
	WHEN ROW_NUMBER()OVER(PARTITION BY patient_id ORDER BY prescription_date::date ) = 1 THEN 'First-time'
	ELSE 'Repeat'
END AS prescription_frequency
FROM prescriptions ;
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
-----------------------------Part 3 Data Analysis
--
--a) Patient Analysis:
--
------------------------------------------------------------------------------------------------------------------------------------
--What is the distribution of patients across age groups?
SELECT age_group , COUNT(*) AS total_patients 
FROM patients_transformed 
GROUP BY 1 
;
--
------------------------------------------------------------------------------------------------------------------------------------
--How does the appointment frequency vary by patient type?
-- Since the data in appintments table is mostly for 2023 year that's why result covered in Longterm and Regular 
SELECT T1.patient_type, COUNT(T2.appointment_id) AS number_of_appointments 
FROM patients_transformed AS T1 
JOIN appointments_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1
;
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--b) Appointment Analysis:
--
--What are the most common appointment types by age group?
--
SELECT T1.age_group, T2.appointment_type, COUNT(*) AS appointment_count 
FROM patients_transformed AS T1 
JOIN appointments_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1,2 
ORDER BY 1
;
--
------------------------------------------------------------------------------------------------------------------------------------
--Are there specific days of the week with higher emergency visits?
SELECT day_of_week , COUNT(*) AS appointment_count 
FROM appointments_transformed 
WHERE appointment_type = 'Emergency' 
GROUP BY 1 
ORDER BY 2 DESC 
;

--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--c) Prescription Analysis:
--
--What are the most prescribed medication categories by age group?
--

SELECT T2.age_group, T1.medication_category, COUNT(*) AS total_patient 
FROM prescriptions_transformed AS T1
JOIN patients_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1,2 
ORDER BY 1
;
--
------------------------------------------------------------------------------------------------------------------------------------
--How does prescription frequency correlate with appointment frequency?
WITH appointment_counts AS (
    SELECT 
        patient_id,
        COUNT(*) AS appointment_count
    FROM appointments_transformed
    GROUP BY patient_id
),
prescription_counts AS (
    SELECT 
        patient_id,
        COUNT(*) AS prescription_count
    FROM prescriptions_transformed
    GROUP BY patient_id
)
SELECT 
    a.patient_id,
    a.appointment_count,
    p.prescription_count
FROM appointment_counts a
JOIN prescription_counts p ON a.patient_id = p.patient_id 
;
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--