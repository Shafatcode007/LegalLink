-- Local test assertion only; never reads a hash into the Flutter app or logs.
do $$
begin
  if not exists (
    select 1 from advocates a join profiles p on p.id = a.profile_id
    where p.full_name = 'Local Advocate'
      and a.pin_hash <> '4826'
      and a.pin_hash = extensions.crypt('4826', a.pin_hash)
  ) then
    raise exception 'Local approval PIN was not hashed correctly';
  end if;
end $$;
