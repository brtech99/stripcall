-- Function to get reporter name from phone number
-- Priority: 1) users table (app users), 2) sms_reporters table (legacy data)
-- Uses normalized phone comparison (digits only, strip leading 1)

-- Helper function to normalize phone numbers
CREATE OR REPLACE FUNCTION normalize_phone(phone TEXT)
RETURNS TEXT AS $$
DECLARE
  digits_only TEXT;
BEGIN
  -- Remove all non-digit characters
  digits_only := regexp_replace(phone, '\D', '', 'g');

  -- Strip leading 1 if it's an 11-digit number (US country code)
  IF length(digits_only) = 11 AND digits_only LIKE '1%' THEN
    digits_only := substring(digits_only from 2);
  END IF;

  RETURN digits_only;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Main function to get reporter name
CREATE OR REPLACE FUNCTION get_reporter_name(reporter_phone TEXT)
RETURNS TEXT AS $$
DECLARE
  normalized_input TEXT;
  result_name TEXT;
  user_record RECORD;
  sms_record RECORD;
BEGIN
  -- Handle null input
  IF reporter_phone IS NULL OR reporter_phone = '' THEN
    RETURN NULL;
  END IF;

  -- Normalize the input phone
  normalized_input := normalize_phone(reporter_phone);

  -- First, check users table (app users)
  FOR user_record IN
    SELECT firstname, lastname, phonenbr
    FROM users
    WHERE phonenbr IS NOT NULL AND phonenbr != ''
  LOOP
    IF normalize_phone(user_record.phonenbr) = normalized_input THEN
      result_name := TRIM(COALESCE(user_record.firstname, '') || ' ' || COALESCE(user_record.lastname, ''));
      IF result_name != '' THEN
        RETURN result_name;
      END IF;
    END IF;
  END LOOP;

  -- Fall back to sms_reporters table (legacy imported data)
  FOR sms_record IN
    SELECT name, phone
    FROM sms_reporters
    WHERE phone IS NOT NULL
  LOOP
    IF normalize_phone(sms_record.phone) = normalized_input THEN
      IF sms_record.name IS NOT NULL AND sms_record.name != '' THEN
        RETURN sms_record.name;
      END IF;
    END IF;
  END LOOP;

  -- No name found
  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION normalize_phone(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION normalize_phone(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_reporter_name(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_reporter_name(TEXT) TO service_role;

COMMENT ON FUNCTION normalize_phone(TEXT) IS 'Normalizes phone number to digits only, strips leading 1 for US numbers';
COMMENT ON FUNCTION get_reporter_name(TEXT) IS 'Gets reporter name by phone number. Checks users table first, then sms_reporters. Returns NULL if not found.';
