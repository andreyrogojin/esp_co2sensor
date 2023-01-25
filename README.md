##### Датчик содержания CO2 в воздухе под управлением esp8622 с прошивкой nodemcu.

Конфигурация nodemcu:

number_type	integer  
modules	adc,bit,bme280_math,dht,encoder,  
file,gpio,gpio_pulse,i2c,net,node,  
ow,pipe,rtcfifo,rtcmem,rtctime,sntp,  
softuart,spi,struct,tmr,uart,ucg,wifi
lfs_size	65536

Не все модули фактически использованы, можно и подсократить.


Список файлов.

- dataread.lua    инициализация и чтение датчика, вывод на индикатор, запись в файл.
- graf.html       загрузка данных из esp в браузер и построение графика.
- init.lua        стартовый файл nodemcu.
- scd40.lua       модуль с функциями для работы с датчиком scd40/scd41
- server.lua      http сервер для управления устройством из браузера.
- tm1637.lua      модуль с функциями для работы с семисегментым индикатором.
