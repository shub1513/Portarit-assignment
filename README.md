# Healthcare Analytics Assignment - 
## Part 1: Data Pipeline Documentation
### 1. Setup Overview
The pipeline was built using Docker, Python, and PostgreSQL. SQL transformations were performed using DBeaver.
Approach A: Docker + PowerShell
- Cloned the repo and navigated using PowerShell
- Installed Docker, Python, and dependencies
- Started the PostgreSQL container using `docker-compose up -d`
- Loaded the dataset using `python load_data.py`
Approach B: DBeaver (GUI)
- Connected to PostgreSQL using DBeaver GUI
- Setup connection using Docker host settings:
  Host: localhost
  Port: 5432
  Username/Password: postgres
- Verified that tables were loaded properly
- Performed transformations using SQL Editor
### 2. Data Quality Checks
- Handled missing ages in patients by assigning 'Not Available' group
- Ensured appointment dates were valid and calculated time gaps between appointments
- Standardized prescription categories by medication name
- Verified provider IDs for consistency
### 3. Design Decision: Non-Destructive Transformations
Instead of modifying the original tables using ALTER TABLE, transformed versions of the tables were created. This modular approach supports clean rollbacks and aligns with best practices in production systems.


### 4. Data Transformations
#### a. patients_transformed
Description: Added age_group and patient_type for better segmentation.
SQL Code:

<pre> 
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
  FROM patients;
 </pre>

•	Issue handled: Missing ages were tagged as 'Not Available'.
#### b. appointments_transformed
Description: Added day_of_week and time gap from last appointment.
SQL Code:
<pre>
CREATE TABLE appointments_transformed AS
SELECT * ,
to_char(appointment_date::date,'Day') AS day_of_week,
(appointment_date::date - LAG(appointment_date::date)
     OVER(PARTITION BY patient_id ORDER BY appointment_date::date)) AS days_since_last_appointment
FROM appointments;
</pre>

•	Issue handled: Handled NULLs using LAG for first appointments.
#### c. prescriptions_transformed
Description: Standardized medication categories and calculated prescription frequency.
SQL Code:
<pre>
CREATE TABLE prescriptions_transformed AS
SELECT * ,
CASE
    WHEN medication_name = 'Ibuprofen' THEN 'Pain Relief'
    WHEN medication_name = 'Metformin' THEN 'Diabetes'
    WHEN medication_name IN ('Lisinopril', 'Aspirin', 'Atorvastatin') THEN 'Heart'
    WHEN medication_name = 'Amoxicillin' THEN 'Antibiotic'
    ELSE 'Others'
END AS medication_category,
CASE
    WHEN ROW_NUMBER() OVER(PARTITION BY patient_id ORDER BY prescription_date::date) = 1 THEN 'First-time'
    ELSE 'Repeat'
END AS prescription_frequency
FROM prescriptions;
</pre>

•	Issue handled: Cleaned and mapped medication names for consistent grouping.


### Analysis Results
#### Question 1 (a)
What is the distribution of patients across age groups?
SQL Code

<pre> SELECT * FROM patients_transformed; </pre>

##### Result Table Screenshot (Partial)

![Screenshot 2025-04-22 100256](https://github.com/user-attachments/assets/2a05a5d3-0960-4f06-81c1-5e80bf310041)

 
##### Chart Screenshot

![Screenshot 2025-04-22 100440](https://github.com/user-attachments/assets/7c2cf62f-386c-4524-b556-d13f9e5ba287)


 
##### Interpretation:
The distribution helps identify which age groups are more actively engaging with the healthcare system. This insight can guide age-specific outreach or resource planning.


#### Question 1 (b)
How does the appointment frequency vary by patient type?
SQL Code
<pre>
SELECT T1.patient_type, COUNT(T2.appointment_id) AS number_of_appointments 
FROM patients_transformed AS T1 
JOIN appointments_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1;
</pre>

##### Result Table Screenshot

 ![Screenshot 2025-04-22 100833](https://github.com/user-attachments/assets/2303f407-9a42-43fa-ac0f-abde99178440)

##### Chart Screenshot

 ![Screenshot 2025-04-22 100906](https://github.com/user-attachments/assets/7a6151dc-e964-457b-8b2e-573307433d46)


##### Interpretation:
New or long-term patients may have different appointment frequencies, which can inform strategies to improve engagement or retention.

#### Question 2 (a)
What are the most common appointment types by age group?
SQL Code
<pre>
SELECT T1.age_group, T2.appointment_type, COUNT(*) AS appointment_count 
FROM patients_transformed AS T1 
JOIN appointments_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1,2 
ORDER BY 1 ;
</pre>

##### Result Table Screenshot

![Screenshot 2025-04-22 101044](https://github.com/user-attachments/assets/47c56e60-59ef-4111-a2d3-e5b62aa2100a)

 
##### Chart Screenshot

![Screenshot 2025-04-22 101109](https://github.com/user-attachments/assets/b573a677-025e-45d4-8d8a-38c8054d6fad)

 
##### Interpretation:
Understanding popular appointment types by age group allows providers to tailor services for specific demographics, enhancing patient satisfaction and care efficiency.

#### Question 2 (b)

Are there specific days of the week with higher emergency visits?
SQL Code
<pre>
SELECT day_of_week , COUNT(*) AS appointment_count 
FROM appointments_transformed 
WHERE appointment_type = 'Emergency' 
GROUP BY 1 
ORDER BY 2 DESC ;
</pre>

##### Result Table Screenshot

![Screenshot 2025-04-22 102205](https://github.com/user-attachments/assets/8211d9d6-cff5-4404-853b-c86088e336ac)
 

##### Chart Screenshot

![Screenshot 2025-04-22 102228](https://github.com/user-attachments/assets/273ea88a-ce8d-460f-b637-bedcaa22934b)

 
##### Interpretation:
Analyzing emergency visit patterns by weekday helps identify operational stress points, enabling better scheduling and resource allocation.


#### Question 3 (a)
What are the most prescribed medication categories by age group?
SQL Code
<pre>
SELECT T2.age_group, T1.medication_category, COUNT(*) AS total_patient 
FROM prescriptions_transformed AS T1
JOIN patients_transformed AS T2 ON T1.patient_id = T2.patient_id 
GROUP BY 1,2 
ORDER BY 1 ;
</pre>

##### Result Table Screenshot (Partial)
 ![Screenshot 2025-04-22 102406](https://github.com/user-attachments/assets/3642984c-9431-4553-9f49-0f842671513f)

##### Chart Screenshot
![Screenshot 2025-04-22 102438](https://github.com/user-attachments/assets/6991d7ea-8ff0-4b5b-8f1e-790b8f80dbd2)
 

##### Interpretation:
Identifying medication categories prescribed most by age group assists in inventory planning, preventive care initiatives, and chronic disease management.


#### Question 3 (b)
How does prescription frequency correlate with appointment frequency?
SQL Code
<pre>
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
</pre>

##### Result Table Screenshot (Partial)

![Screenshot 2025-04-22 102714](https://github.com/user-attachments/assets/05c2642d-4356-42d6-890a-541512bb4f3f)
 

##### Chart Screenshot
 
![Screenshot 2025-04-22 102806](https://github.com/user-attachments/assets/781114a6-438b-4152-ae0c-e709b4082c25)

![Screenshot 2025-04-22 102825](https://github.com/user-attachments/assets/5b04b33f-83fd-4f90-b4a2-2ca14ad77d6a)


##### Interpretation:
A correlation between appointment and prescription frequencies may indicate whether higher patient engagement results in more active treatment or monitoring.


### Business Insights
#### Insight 1
Finding: The majority of patients fall in the 70+ age group, indicating high engagement from senior patients.

Suggestion: Enhance preventive and wellness programs tailored for seniors (70+ age group).
#### Insight 2
Finding: Emergency visits peak on Friday with 9 visits.

Suggestion: Bolster staffing and introduce end of week tele triage support to smooth Friday surges.
#### Insight 3
Finding: Regular patients (6–24 months since registration) have the highest appointment count (56), ahead of long term (45) and new patients (4).

Suggestion: Investigate which touchpoints drive strong engagement in this group and replicate them for new and long term cohorts.
#### Insight 4
Finding: Heart medications are the top prescription category for older age groups (24 for 70+, 20 for 51–70).

Suggestion: Review cardiovascular drug inventory and patient education to ensure adherence and supply continuity.
#### Insight 5
Finding: Patients with more appointments also receive more prescriptions, suggesting comprehensive care but raising overtreatment questions.

Suggestion: Perform an outcome analysis to confirm whether higher visit to prescription ratios improve health metrics or signal unnecessary prescribing.
#### Insight 6
Finding: Among the 51+ cohort, Checkup is the most common appointment type, reflecting a preventive care focus

Suggestion: Expand proactive screening and chronic disease management initiatives to leverage this preventive mindset.
