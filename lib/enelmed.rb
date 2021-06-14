require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'

require 'net/smtp'

class Enelmed
  include Capybara::DSL
  VISIT_FILE = "visit.txt"

  DEFAULT_DATE_VALIDATOR = ->(date) { date && date > (DateTime.now + 1.0/24*3) }

  def initialize(
    login:,
    password:,
    city:,
    email_from:,
    email_to:,
    service_type:,
    service:,
    date_validator: DEFAULT_DATE_VALIDATOR,
    dryrun: false,
    headless: true,
    visit_lock: VISIT_FILE
  )
    @date_validator = date_validator
    @dryrun = dryrun
    @headless = headless
    @visit_lock = visit_lock
    @login = login
    @password = password
    @city = city
    @service_type = service_type
    @service = service
    @email_from = email_from
    @email_to = email_to
  end

  def call
    check_lockfile!
    initialize_capybara

    login
    submit_search_form
    new_visit = browse_visits
    new_visit_summary = new_visit.text

    send_emails(@email_from,[@email_to], 'Wolny termin w enelmedzie!',new_visit_summary)

    new_visit.click_on('Rezerwuj')
    check 'Akceptuję Regulamin wizyt w Oddziałach'
    click_on 'Potwierdzam' if not @dryrun
    debug "Reservation complete!"

    send_emails(@email_from,[@email_to], 'Zarezerwowany termin w enelmedzie!',new_visit_summary)
    File.write(VISIT_FILE, "Zarezerwowany termin w enelmedzie!\n\n#{new_visit_summary}")
    debug "Email sent"
    debug "Complete"

  rescue Capybara::ElementNotFound => e
    debug "Got an error!"
    debug e
    debug "Retrying in 1 minute ..."
    sleep 60
    retry
  end

  private

  def debug(msg)
    STDERR.puts msg
  end

  def login
    visit '/Account/Login'
    fill_in 'Login', with: @login
    fill_in 'Hasło', with: @password
    check 'Akceptuję regulamin'
    click_on 'Zaloguj się'
  end

  def submit_search_form
    visit '/Visit/New'
    has_content? 'Umów teleporadę, wizytę lub badanie'
    debug "Logged in ..."

    # Zapoznaj się z aktualną Polityką prywatności
    if has_css? '.js-close-popover'
      find('.js-close-popover').click
    end

    click_on_select 'City'
    select @city
    # select 'Warszawa'

    click_on_select 'Department'
    check_all_boxes_for 'Department'

    click_on_select 'ServiceType'
    select @service_type

    click_on_select 'Service'
    select @service

    uncheck 'ForeignLanguageDoctor'

    click_on_select 'Doctor'
    check_all_boxes_for 'Doctor'

    click_on_select 'VisitDateFrom'

    within 'label[for="VisitDateFrom"]+.date-range' do
      within '.dtp_input1' do
        find('th.today').click
        sleep 1
      end

      within '.dtp_input2' do
        find('th.today').click
        sleep 1
        9.times { find('th.next').click }
        days = find_all('td.day:not(.old):not(.new):not(.disabled)')
        day = days[Date.today.day] || days.last
        day.click
        sleep 1
      end

      click_on "Zapisz"
    end

    click_on 'Szukaj'

    debug "Query sent ..."
  end

  def browse_visits
    debug "Got response. Looking for visits ..."

    new_visit = nil
    repeat = true
    while repeat
      has_content? 'Znalezione wizyty'
      within('#Results') do
        debug "Load complete"
        new_visit = find_all('.box-visit').
          select { |node| node.has_content? '0,00 zł', wait: 0 }.
          find { |node| @date_validator.call(parse_node_datetime(node)) }
        # debugger
        if new_visit
          repeat = false
          break
        end
        next_button = first('.pagination .active ~ .print-hide a') rescue nil
        if not next_button
          repeat = false
          break
        end
        next_button.click
        debug "Waiting for page to load ... "
        # sleep 20
        # while has_css?('#Loader', wait: 2)
        #   sleep 2
        # end
      end
    end

    if not new_visit
      debug "No visit found, sorry"
      exit 1
    else
      debug "Got a visit!"
    end

    new_visit
  end


  def check_lockfile!
    if File.exists?(@visit_lock)
      debug "Visit lock file #{@visit_lock.inspect} already exists!"
      debug '-' * 40
      debug File.read(@visit_lock)
      debug '-' * 40
      exit 1
    end
  end

  def initialize_capybara
    Capybara.run_server = false
    # Capybara.current_driver = :selenium
    Capybara.current_driver = @headless ? :selenium_headless : :selenium
    Capybara.app_host = 'https://online.enel.pl'
    Capybara
    Capybara.default_max_wait_time = 5
  end

  def parse_node_datetime(node)
    date_str = node.find_all('p.text-lead', wait: 0).find { |n| n.has_css?('.ti-calendar') }.text.match(/[\d\.]+/)[0]
    time_str = node.find_all('p.text-lead', wait: 0).find { |n| n.has_css?('.ti-alarm-clock') }.text.match(/[\d:]+/)[0]
    date = DateTime.strptime("#{date_str} #{time_str}", '%d.%m %H:%M')
    date = date.next_year if date < Date.today
    # debug "parsed\n#{date_str.inspect}\nand\n#{time_str.inspect}\n as: #{date}\n"
    date
  rescue Selenium::WebDriver::Error::StaleElementReferenceError => e
    debug "Got an error!"
    debug e
    nil
  end

  def click_on_select(label_id, **args)
    sleep 1
    find(%w[select dropdown date-range].map { |cls| "label[for=\"#{label_id}\"]+.#{cls}" }.join(', '), **args).click
  end

  def check_all_boxes_for(label_id)
    sleep 1
    within "label[for=\"#{label_id}\"]+.dropdown" do
      has_content? 'Zatwierdź'
      find_all('input[type="checkbox"]').reject(&:checked?).each(&:click)
      click_on 'Zatwierdź'
    end
  end


  def send_emails(sender_address, recipients, subject, message_body, smtp_server: 'localhost', smtp_port: 25)
    recipients.each do |recipient_address|
      message_header =''
      message_header << "From: <#{sender_address}>\r\n"
      message_header << "To: <#{recipient_address}>\r\n"
      message_header << "Subject: #{subject}\r\n"
      message_header << "Date: " + Time.now.to_s + "\r\n"
      message = message_header + "\r\n" + message_body + "\r\n"
      Net::SMTP.start(smtp_server, smtp_port) do |smtp|
        smtp.send_message message, sender_address, recipient_address
      end
    end
  end
end
