Given(/^the book has an RFID\-tag$/) do
  #@tnr = "882715"
end

Given(/^the book is placed on the shelf$/) do
  #@book = Book.new.find(@tnr)
  #visit "/book/"+@tnr
end

Then(/^I should see the title and author of the book$/) do
  #session = Capybara::Session.new(:current, @book)
  #visit "/omtale/"+@tnr
  #page.should have_content "Panserhjerte"
end

