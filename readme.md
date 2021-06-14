# Enelbot

Bot służący do rezerwowania terminów w enelmedzie, napisany ponieważ
przez pół roku nie mogłem znaleść terminu na USG kolana.

## Instalacja

Najpierw trzeba zainstalować rubiego, następnie zrobić `bundle install`

## Uruchomienie

```
env LOGIN=login' \
	PASSWORD='password'\
	CITY='Kraków'\
	SERVICE_TYPE='USG'\
	SERVICE='USG 2 stawów kolanowych'\
	EMAIL_TO='real_email@gmail.com'\
	TEST=true\
	do_reservation.rb
```

I jeśli wszystko zadziała, to należy skasować plik `visits.txt` i usunąć
flagę `TEST=true`. Polecam to wrzucić w crona i czekać na maila.

Działa dla wizyt na które ma się skierowanie w systemie lub nie jest ono
wymagane.
