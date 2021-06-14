#!/usr/bin/env ruby

require 'byebug'
require 'rubygems'
require_relative 'lib/enelmed'

test_mode = true && ENV.fetch('TEST', 'false').to_s.upcase[0] = 'T'

Enelmed.new(
  login: ENV.fetch('LOGIN'), #
  password: ENV.fetch('PASSWORD'), #
  city: ENV.fetch('CITY'), # 'Kraków'
  # city: 'Warszawa',
  service_type: ENV.fetch('SERVICE_TYPE'), # 'USG'
  service: ENV.fetch('SERVICE'), # 'USG 2 stawów kolanowych'
  email_from: 'enelsnif@localhost',
  email_to: ENV.fetch('EMAIL_TO'), #
  visit_lock: "visit.txt",
  date_validator: ->(date) { date && date > DateTime.now + 1.0/24*3 },
  headless: !test_mode,
  dryrun: test_mode
).call
