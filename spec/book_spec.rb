require_relative '../lib/book'
require 'bogus/rspec'
require 'typhoeus'

describe "Book" do

	subject(:book) {Book.new}

	def fake_response(body)
		Typhoeus::Response.new(code: 200, body: body)
	end

	describe "Goodreads" do
		let(:response) { fake_response(File.open('spec/goodreads.xml').read) }

		context "Goodreads response" do

			before {book.Goodreads(response)}

			it "saves source of rating" do
				book.rating[:source].should == "Goodreads"
			end
			it "saves description" do
				book.review_collection.should include {|r| r[:source] == "Goodreads"} 
			end
			it "saves sum of ratings" do
				book.rating[:rating].should == 596
			end
			it "saves number of ratings" do
				book.rating[:num_raters].should == 159
			end

		end

	end
end