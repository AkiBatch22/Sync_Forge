if Rails.env.test?
  puts "Skipping demo seeds in the test environment."
else
  load Rails.root.join("db/demo_seeds.rb")
end
