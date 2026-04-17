-- Fix : trigger handle_new_user exception-safe + grants pour supabase_auth_admin
-- Sans ce fix, un signup OTP phone cause "Database error saving new user" (500)
-- car l'insertion dans profiles peut échouer silencieusement et bloque
-- la création de l'user auth.

-- 1. Grants nécessaires pour que le trigger s'exécute correctement
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT INSERT ON public.profiles TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;

-- 2. Trigger tolérant aux erreurs (si insert profile fail, on log mais
-- on ne casse pas la création du user auth)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id, full_name, phone, email)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone', ''),
      NEW.email
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user failed for user %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
