/* Formatted on 9/19/2024 12:15:53 PM (QP5 v5.256.13226.35510) */
CREATE OR REPLACE PROCEDURE ds_fisc_it_validation_prc (
   p_cur_ds_tins_obj              ds_tins_obj,
   p_in_ds_id                     ds_master_m.ds_id%TYPE,
   p_chr_mailing_ctry             VARCHAR2,
   p_chr_first_name               VARCHAR2,
   p_chr_middle_name              VARCHAR2,
   p_chr_last_name                VARCHAR2,
   p_chr_gender                   VARCHAR2,
   p_chr_subregion                VARCHAR2,
   p_chr_birthplace               VARCHAR2,
   p_dte_date_of_birth            DATE,
   p_chr_debug_flag               VARCHAR2 DEFAULT 'N',
   p_chr_user_name                VARCHAR2,
   x_out_chr_validated_flag   OUT VARCHAR2,
   x_out_chr_validated_tin    OUT VARCHAR2)
IS
   x_num                 NUMBER := 0;        --Use to Identify validation code
   x_num2                NUMBER := 0;        --Use to Identify validation code
   x_chr                 VARCHAR2 (3);       --Use to Identify validation code
   l_chr_string          VARCHAR2 (500) := NULL; -- Holds intermediate data first name or last name
   l_chr_cons_string     VARCHAR2 (500) := NULL; -- Holds intermediate  consonant data
   l_chr_vowel_string    VARCHAR2 (500) := NULL; -- Holds intermediate  vowel data
   l_chr_drv_fname       VARCHAR2 (3);
   l_chr_drv_lname       VARCHAR2 (3);
   l_chr_yob             VARCHAR2 (3);
   l_chr_mob             VARCHAR2 (3);
   l_chr_dob             VARCHAR2 (3);
   l_chr_pob             VARCHAR2 (5);
   l_out_char_message    VARCHAR2 (3000);
   l_chr_process_flag    CHAR (1);
   l_num_tin_id          NUMBER;

   l_chr_mailing_ctry    VARCHAR2 (50);
   l_chr_first_name      VARCHAR2 (50);
   l_chr_middle_name     VARCHAR2 (50);
   l_chr_last_name       VARCHAR2 (50);
   l_dte_date_of_birth   VARCHAR2 (50);
   l_chr_gender          VARCHAR2 (50);
   l_chr_birthplace      VARCHAR2 (50);
   l_chr_subregion       VARCHAR2 (50);
   l_chr_tin_number      VARCHAR2 (50);

   TYPE l_num_validation_tbl IS TABLE OF NUMBER;

   l_num_val_tbl         l_num_validation_tbl;
BEGIN
   BEGIN
      SELECT tin_id
        INTO l_num_tin_id
        FROM md_tin_m
       WHERE tin_code = 'FISC' AND tin_country = 'IT';
   EXCEPTION
      WHEN OTHERS
      THEN
         l_chr_process_flag := 'N';
   END;

   -- Default set flag value to null , only if validation is passed then set to Y
   x_out_chr_validated_flag := 'N';

   -- If input parameters are null, try to see if DS IS existing and get the data

   IF     (   (p_chr_gender IS NULL)
           OR (p_chr_subregion IS NULL)
           OR (p_chr_birthplace IS NULL)
           OR (p_dte_date_of_birth IS NULL))
      AND p_in_ds_id IS NOT NULL
   THEN
      l_chr_tin_number := NVL (p_cur_ds_tins_obj.tin_number, 'X');
      l_chr_mailing_ctry := NVL (p_chr_mailing_ctry, 'X');
      l_chr_first_name := p_chr_first_name;
      l_chr_middle_name := p_chr_middle_name;
      l_chr_last_name := p_chr_last_name;
      l_dte_date_of_birth := p_dte_date_of_birth;
      l_chr_gender := p_chr_gender;
      l_chr_birthplace := p_chr_birthplace;
      l_chr_subregion := p_chr_subregion;
   END IF;


   CASE
      -- No Country_of_mailing check as confirmed by MW/Application team - will be handled their side
      -- If Gender/DOB/State/City is missing then donot process request
      WHEN (   (l_chr_gender IS NULL)
            OR (l_chr_birthplace IS NULL)
            OR (l_chr_subregion IS NULL)
            OR (l_dte_date_of_birth IS NULL))
      THEN
         l_chr_process_flag := 'N';
      ELSE
         l_chr_process_flag := 'Y';
   END CASE;

   IF l_chr_process_flag = 'Y'
   THEN
      --Assign first name and derive fisc value SN
      BEGIN
         l_chr_string := NULL;
         --clean name and populate to intermediate variable, only characters should go in the name
         l_chr_string :=
            UPPER (
               NVL (
                  REGEXP_REPLACE (
                     l_chr_first_name || NVL (l_chr_middle_name, ''),
                     '[^A-Za-z]',
                     ''),
                  'X'));

         --Get Consonants and vowels to two differenr strings
         l_chr_cons_string := REGEXP_REPLACE (l_chr_string, '[A,E,I,O,U]', '');
         l_chr_vowel_string :=
            REGEXP_REPLACE (l_chr_string, '[^A,E,I,O,U]', '');

         IF l_chr_cons_string IS NOT NULL
         THEN
            IF LENGTH (l_chr_cons_string) = 1
            THEN
               l_chr_drv_fname :=
                  l_chr_cons_string || SUBSTR (l_chr_vowel_string, 1, 2);
            ELSIF LENGTH (l_chr_cons_string) = 2
            THEN
               l_chr_drv_fname :=
                  l_chr_cons_string || SUBSTR (l_chr_vowel_string, 1, 1);
            ELSIF LENGTH (l_chr_cons_string) = 3
            THEN
               l_chr_drv_fname := l_chr_cons_string;
            ELSIF LENGTH (l_chr_cons_string) > 3
            THEN
               l_chr_drv_fname :=
                     SUBSTR (l_chr_cons_string, 1, 1)
                  || SUBSTR (l_chr_cons_string, 3, 2);
            END IF;
         ELSE
            l_chr_drv_fname := SUBSTR (l_chr_vowel_string, 1, 2);
         END IF;

         -- If still the length   of the  name  < 3  then append with 'X'
         WHILE LENGTH (NVL (l_chr_drv_fname, 'X')) < 3
         LOOP
            l_chr_drv_fname := l_chr_drv_fname || 'X';
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      --Assign first  name and derive fisc value EN
      --Assign last name and derive fisc value SN
      BEGIN
         l_chr_string := NULL;
         l_chr_cons_string := NULL;
         l_chr_vowel_string := NULL;

         l_chr_string :=
            UPPER (
               NVL (REGEXP_REPLACE (l_chr_last_name, '[^A-Za-z]', ''), 'X'));

         --Get Consonants and vowels to two differenr strings
         l_chr_cons_string := REGEXP_REPLACE (l_chr_string, '[A,E,I,O,U]', '');
         l_chr_vowel_string :=
            REGEXP_REPLACE (l_chr_string, '[^A,E,I,O,U]', '');

         IF l_chr_cons_string IS NOT NULL
         THEN
            IF LENGTH (l_chr_cons_string) = 1
            THEN
               l_chr_drv_lname :=
                  l_chr_cons_string || SUBSTR (l_chr_vowel_string, 1, 2);
            ELSIF LENGTH (l_chr_cons_string) = 2
            THEN
               l_chr_drv_lname :=
                  l_chr_cons_string || SUBSTR (l_chr_vowel_string, 1, 1);
            ELSIF LENGTH (l_chr_cons_string) >= 3
            THEN
               l_chr_drv_lname := SUBSTR (l_chr_cons_string, 1, 3);
            END IF;
         ELSE
            l_chr_drv_lname := SUBSTR (l_chr_vowel_string, 1, 2);
         END IF;

         -- If still the length   of the  name  < 3  then append with 'X'
         WHILE LENGTH (NVL (l_chr_drv_lname, 'X')) < 3
         LOOP
            l_chr_drv_lname := l_chr_drv_lname || 'X';
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      --Assign last name and derive fisc value EN

      --Get YOB,MOB,DOB SN
      IF l_dte_date_of_birth IS NOT NULL
      THEN
         SELECT SUBSTR (TO_CHAR (l_dte_date_of_birth, 'yyyy'), -2),
                DECODE (TO_CHAR (l_dte_date_of_birth, 'mm'),
                        '01', 'A',
                        '02', 'B',
                        '03', 'C',
                        '04', 'D',
                        '05', 'E',
                        '06', 'H',
                        '07', 'L',
                        '08', 'M',
                        '09', 'P',
                        '10', 'R',
                        '11', 'S',
                        '12', 'T'),
                DECODE (
                   l_chr_gender,
                   'M', TO_CHAR (l_dte_date_of_birth, 'DD'),
                   'F', TO_CHAR (
                             TO_NUMBER (TO_CHAR (l_dte_date_of_birth, 'DD'))
                           + 40))
           INTO l_chr_yob, l_chr_mob, l_chr_dob
           FROM DUAL;
      END IF;

      --Get YOB,MOB,DOB EN

      BEGIN
         -- As per  comment when more than one value found take the first one as Place of birth
         --In this case min value is the first one below are eg
         --(A744    BELLAGIO    COMO) , ( M335    BELLAGIO    COMO)

         SELECT MIN (chr_attribute1)
           INTO l_chr_pob
           FROM xx_location_m
          WHERE     country_code = 'IT'
                AND state_name = l_chr_subregion
                AND chr_attribute1 IS NOT NULL
                AND city = l_chr_birthplace;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      x_out_chr_validated_tin :=
            l_chr_drv_lname
         || l_chr_drv_fname
         || l_chr_yob
         || l_chr_mob
         || l_chr_dob
         || l_chr_pob;

      -- Validation Code:Calculation
      BEGIN
         l_num_val_tbl :=
            l_num_validation_tbl (1,
                                  0,
                                  5,
                                  7,
                                  9,
                                  13,
                                  15,
                                  17,
                                  19,
                                  21,
                                  2,
                                  4,
                                  18,
                                  20,
                                  11,
                                  3,
                                  6,
                                  8,
                                  12,
                                  14,
                                  16,
                                  10,
                                  22,
                                  25,
                                  24,
                                  23);

         FOR i IN 1 .. LENGTH (SUBSTR (x_out_chr_validated_tin, 1, 15))
         LOOP
            x_num := ASCII (SUBSTR (x_out_chr_validated_tin, i, 1));

            IF MOD (i, 2) = 0
            THEN
               IF x_num >= ASCII ('0') AND x_num <= ASCII ('9')
               THEN
                  x_num2 := x_num2 + x_num - ASCII ('0');
               ELSE
                  x_num2 := x_num2 + x_num - ASCII ('A');
               END IF;
            ELSE
               IF x_num >= ASCII ('0') AND x_num <= ASCII ('9')
               THEN
                  x_num2 := x_num2 + l_num_val_tbl (x_num - ASCII ('0') + 1);
               ELSE
                  x_num2 := x_num2 + l_num_val_tbl (x_num - ASCII ('A') + 1);
               END IF;
            END IF;
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      -- Validation Code Final value
      x_chr := CHR (ASCII ('A') + MOD (x_num2, 26));

      x_out_chr_validated_tin :=
            l_chr_drv_lname
         || l_chr_drv_fname
         || l_chr_yob
         || l_chr_mob
         || l_chr_dob
         || l_chr_pob
         || x_chr;
   END IF;

   x_out_chr_validated_flag := 'N';

   IF p_chr_debug_flag = 'Y'
   THEN
      NULL;
   END IF;

   -- If calculated TIN doesn't match with entered TIN
   IF l_chr_tin_number <> NVL (x_out_chr_validated_tin, 'Z')
   THEN
      l_out_char_message := 'Not matching ...';
      x_out_chr_validated_flag := 'N';
      NULL;
   ELSE
      x_out_chr_validated_flag := 'Y';
   END IF;
EXCEPTION
   WHEN OTHERS
   THEN
      NULL;
END;
/
