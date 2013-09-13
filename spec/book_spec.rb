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

		context "Rating" do
			it "saves source of rating" do
				book.Goodreads(response)
				book.rating[:source].should == "Goodreads"
			end
		end

	end
end