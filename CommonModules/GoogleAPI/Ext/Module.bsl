﻿#Область Авторизация_в_Google

//Код доступа можно получить, авторизовавшись на сайте и разрешив доступ к соответствующим разрешениям
//Можно сделать, например, HTML-поле. Подробнее на сайте https://developers.google.com/identity/protocols/oauth2
//Пример реализации так же на Github (Обработка GoogleAPI_GetCode)
Функция ПолучитьКодДоступа()
	Возврат "КодДоступа";
КонецФункции


//По известному КодуДоступа имеется возможность получить токен доступа
//Возвращает структуру, содержащую:
//"Result" — Истина, если выполнено без ошибок. Иначе ложь.
//"AccessToken" — строка, содержащая токен доступа
//"RefreshToken" — строка, содержащая токен обновления
//"LifeTime" — время жизни токена
Функция ПолучитьТокен(КодДоступа, ИДКлиента, СекретКлиента)
	Сервер = "accounts.google.com";
	Порт = 443;
	Ресурс = "/o/oauth2/token"; 	
	СтрокаЗапроса = СтрШаблон("client_id=%1&client_secret=%2&grant_type=authorization_code&code=%3&redirect_uri=http://localhost", 
		ИДКлиента, 
		СекретКлиента, 
		КодДоступа);

	Соединение = Новый HTTPСоединение(Сервер, Порт,,,,,Новый ЗащищенноеСоединениеOpenSSL);

	Заголовки  = Новый Соответствие;
	Заголовки.Вставить("Content-Type","application/x-www-form-urlencoded");
	
	ЗапросХТТП = Новый HTTPЗапрос(Ресурс, Заголовки);
	ЗапросХТТП.УстановитьТелоИзСтроки(СтрокаЗапроса);
	Попытка
		Ответ = Соединение.ВызватьHTTPМетод("POST",ЗапросХТТП);
		
		Если Не Ответ.КодСостояния = 200 Тогда
			Структура = Новый Структура;
			Структура.Вставить("Result", Ложь);
			Возврат Структура; 
		КонецЕсли;
	Исключение
		Структура = Новый Структура;
		Структура.Вставить("Result", Ложь);
		Возврат Структура;	
	КонецПопытки;

	Строка = Ответ.ПолучитьТелоКакСтроку();
	
    Чтение = Новый ЧтениеJSON();
	Чтение.УстановитьСтроку(Строка);

	Фабрика = ФабрикаXDTO.ПрочитатьJSON(Чтение);
	
    Чтение.Закрыть();
	Структура = Новый Структура;
	Структура.Вставить("Result", Истина);
	Структура.Вставить("AccessToken", Фабрика.access_token);
	Структура.Вставить("RefreshToken", Фабрика.refresh_token);
	Структура.Вставить("LifeTime", ТекущаяДата()+Число(Фабрика.expires_in));
	Возврат Структура;	
КонецФункции

//Токен лишь временный, и чтобы не прибегать к постоянному использованию авторизации в HTML форме, токен можно продлить
//Для этого нужен RefreshToken (токен обновления)
//Возвращает структуру, содержащую:
//"Result" — Исьига есди выполнено без ошибок. Иначе ложь;
//"AccessToken" — строка, содержащая токен доступа (новый)
//"LifeTime" — время жизни нового токена
Функция ОбновитьТокен(ТокенОбновления, ИДКлиента, СекретКлиента)
	ЧастьЗапроса = 	"client_id="+ИДКлиента+"&"+
					"client_secret="+СекретКлиента+"&"+
					"refresh_token="+ТокенОбновления+"&"+
					"grant_type=refresh_token";
	
	АдресАвторизации = "/token?";
	Соединение = Новый HTTPСоединение("oauth2.googleapis.com", 443,,,,,Новый ЗащищенноеСоединениеOpenSSL);
	Ресурс = АдресАвторизации + ЧастьЗапроса;
	Заголовки  = Новый Соответствие;
	Заголовки.Вставить("Content-Type", "application/x-www-form-urlencoded");
	Запрос = Новый HTTPЗапрос(Ресурс, Заголовки);
	Попытка
    	Ответ = Соединение.ОтправитьДляОбработки(Запрос);
		
		Если Ответ.КодСостояния <> 200 Тогда
			Структура = Новый Структура;
			Структура.Вставить("Result", Ложь);	
		КонецЕсли;
    	ЧтениеJSON = Новый ЧтениеJSON;
    	ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
    	Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
	Исключение
		Структура = Новый Структура;
		Структура.Вставить("Result", Ложь);
		Возврат Структура;
	КонецПопытки;	
	НовыйТокен = Данные.access_token;
	Возврат НовыйТокен;
	Структура = Новый Структура;
	Структура.Вставить("Result", Истина);
	Структура.Вставить("AccessToken", Данные.access_token);
	Структура.Вставить("LifeTime", ТекущаяДата()+Число(Данные.expires_in));
	Возврат Структура;
КонецФункции
#КонецОбласти

#Область Функции_API
//Каждая функция возвращает "Неопределено", если в процессе выполнения не произошло ошибок. Иначе возвращает строку, содержащую ошибку.

//Создается таблица, используя ТокенДоступа и APIKey.
//Токен доступа - в разделе авторизация
//APIKey можно получить в консоли разработчика Google
//Вы можете получить ссылку на таблицу и ID таблицы из переменной "Данные". 
//JSONДляСозданияТаблицы создается в разделе Формирование JSON
Функция СоздатьТаблицу(ТокенДоступа, ApiKey, JSONДляСозданияТаблицы)
	Соединение = Новый HTTPСоединение("sheets.googleapis.com", 443,,,,,Новый ЗащищенноеСоединениеOpenSSL);
	
	Заголовки  = Новый Соответствие;
	Заголовки.Вставить("Authorization","Bearer " + ТокенДоступа);
	Заголовки.Вставить("Content-Type", "application/json");
	Заголовки.Вставить("Accept", "application/json");

	Ресурс = "/v4/spreadsheets?key="+ApiKey;
	Запрос = Новый HTTPЗапрос(Ресурс, Заголовки);
	Запрос.УстановитьТелоИзСтроки(JSONДляСозданияТаблицы);
	Попытка
    	Ответ = Соединение.ОтправитьДляОбработки(Запрос);
		
		Если Ответ.КодСостояния <> 200 Тогда
			Возврат "Код состояния ответа сервера — " + Строка(Ответ.КодСостояния)+".";
		КонецЕсли;
    	ЧтениеJSON = Новый ЧтениеJSON;
    	ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
    	Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
	Исключение
		Возврат "Ошибка в процессе чтения ответа.";
	КонецПопытки;
	Возврат Неопределено;
КонецФункции

//Функция очищает таблицу с ID "IDТаблицы", используя ТокенДоступа и API Key и ID таблицы
//APIKey можно получить в консоли разработчика Google
//ТокенДоступа создается в разделе "Авторизация"
Функция ОчиститьТаблицу(IDТаблицы, ТокенДоступа, ApiKey)
	JSON = JSON_ОчищениеТаблицы();
	Соединение = Новый HTTPСоединение("sheets.googleapis.com", 443,,,,,Новый ЗащищенноеСоединениеOpenSSL);
	
	Заголовки  = Новый Соответствие;
	Заголовки.Вставить("Authorization","Bearer " + ТокенДоступа);
	Заголовки.Вставить("Content-Type", "application/json");
	Заголовки.Вставить("Accept", "application/json");

	Ресурс = "/v4/spreadsheets/"+IDТаблицы+"/values:batchClear?key="+ApiKey;
	Запрос = Новый HTTPЗапрос(Ресурс, Заголовки);
	Запрос.УстановитьТелоИзСтроки(JSON);
	Попытка
    	Ответ = Соединение.ОтправитьДляОбработки(Запрос);
		
		Если Ответ.КодСостояния <> 200 Тогда
			Возврат "Код состояния ответа сервера — " + Строка(Ответ.КодСостояния)+".";
		КонецЕсли;
		
    	ЧтениеJSON = Новый ЧтениеJSON;
    	ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
    	Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
	Исключение
		Возврат "Ошибка в процессе чтения ответа.";
	КонецПопытки;	
	Возврат Неопределено;
КонецФункции

//Функция записывает данные в таблицу с заданным ID с использованием токена доступа и ключа API
//Токен доступа можно получить в разделе авторизации
//API Key можно получить в консоли разработчика Google
//JSONДляЗаписиДанныхВТаблицу создается в разделе Формирование JSON
Функция ЗаписатьДанныеВТаблицу(IDТаблицы,ТокенДоступа ,APIKey, JSONДляЗаписиДанныхВТаблицу)
	Соединение = Новый HTTPСоединение("sheets.googleapis.com", 443,,,,,Новый ЗащищенноеСоединениеOpenSSL);
	Заголовки  = Новый Соответствие;
	Заголовки.Вставить("Authorization","Bearer " + ТокенДоступа);
	Заголовки.Вставить("Content-Type", "application/json");
	Заголовки.Вставить("Accept", "application/json");

	Ресурс = "/v4/spreadsheets/"+IDТаблицы+"/values/"+СтрЗаменить(JSONДляЗаписиДанныхВТаблицу.Range, ":", "%3A")+"?valueInputOption=RAW&key="+APIKey;
	Запрос = Новый HTTPЗапрос(Ресурс, Заголовки);
	Запрос.УстановитьТелоИзСтроки(JSONДляЗаписиДанныхВТаблицу.JSON);
	Попытка
    	//Ответ = Соединение.ОтправитьДляОбработки(Запрос);
		Ответ = Соединение.ВызватьHTTPМетод("PUT", Запрос);
		
		Если Ответ.КодСостояния <> 200 Тогда
			Возврат "Код состояния ответа сервера — " + Строка(Ответ.КодСостояния)+".";
		КонецЕсли;

    	ЧтениеJSON = Новый ЧтениеJSON;
    	ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
    	Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
		Если Ответ.КодСостояния <> 200 Тогда
			ПодробнаяОшибка = Ответ.ПолучитьТелоКакСтроку();
		КонецЕсли;
	Исключение
		Возврат "Ошибка в процессе чтения ответа.";
	КонецПопытки;;	
	Возврат Данные;
	
	Возврат Неопределено;
КонецФункции
#КонецОбласти

#Область Формирование_JSON
//Функция возвращает JSON (в формате строки), необходимый для создания таблицы
//В качестве параметра МассивСтруктурПараметров — массив структур, каждая структура которого имеет ключ "Название" — название таблицы
Функция JSON_СозданиеТаблицы(НазваниеТаблицы, КоличествоЛистов, МассивСтруктурПараметров)
	JSON = Новый ЗаписьJSON();
	ПараметрыЗаписиJSON = Новый         
        ПараметрыЗаписиJSON(ПереносСтрокJSON.Нет,"",ложь,ЭкранированиеСимволовJSON.Нет,Ложь,Ложь,Ложь,Ложь,Ложь);

	JSON.УстановитьСтроку(ПараметрыЗаписиJSON);
	Структура = Новый Структура;
		
	Properties = Новый Структура;
	Properties.Вставить("title", НазваниеТаблицы);
	Структура.Вставить("properties", Properties);
	
	Sheets = Новый Массив;
	Для Индекс = 0 По КоличествоЛистов-1 Цикл
		Sheet = Новый Структура;
		SheetProperties = Новый Структура;
		SheetProperties.Вставить("title", МассивСтруктурПараметров[Индекс].Название);
		
		Sheet.Вставить("properties", SheetProperties);
		
		Sheets.Добавить(Sheet);
	КонецЦикла;
	Структура.Вставить("sheets", Sheets);
	ЗаписатьJSON(JSON, Структура);
	Возврат JSON.Закрыть();
КонецФункции

//Функция возвращает структуру:
//"JSON" — JSON для отправки на сервер для заполнения таблицы
//"RANGE" — строка, означающая область, которую затрагивает изменение (например, "A1:C30").
//Важно. Количество колонок ТЗ не должно превышать 23.
Функция JSON_ЗаполнениеТаблицы(ТЗ)
	Если (ТЗ.Количество() = 0) Тогда
		Возврат Неопределено;
	КонецЕсли;
	JSON = Новый ЗаписьJSON();
	ПараметрыЗаписиJSON = Новый         
        ПараметрыЗаписиJSON(ПереносСтрокJSON.Нет,"",ложь,ЭкранированиеСимволовJSON.Нет,Ложь,Ложь,Ложь,Ложь,Ложь);
	JSON.УстановитьСтроку(ПараметрыЗаписиJSON);
	Структура = Новый Структура;
	КоличествоСтолбцов = ТЗ.Колонки.Количество();
	Буквы = "ABCDEFGHIJKLMNOPQRSTUVW";
	Если (КоличествоСтолбцов >  СтрДлина(Буквы)) Тогда
		Возврат Неопределено;
	КонецЕсли;
	Буква = Сред(Буквы,КоличествоСтолбцов,1);
	КоличествоСтрок = ТЗ.Количество();
	Range = "A1:"+Буква+Строка(Формат(КоличествоСтрок+1, "ЧГ="));
	Структура.Вставить("range", Range);
	
	Values = Новый Массив;
	Шапка = Новый Массив;                 
	СоответствиеТипов = Новый Соответствие;
	Для каждого Колонка из ТЗ.Колонки Цикл
		СоответствиеТипов.Вставить(Строка(Колонка.Имя), Колонка.ТипЗначения);
		Шапка.Добавить(СтрЗаменить(Строка(Колонка.Имя),"""", ""));
	КонецЦикла;
	Values.Добавить(Шапка);
	Для Индекс = 0 По КоличествоСтрок-1 Цикл
		Value = Новый Массив;
		Строка = ТЗ.Получить(Индекс);
		Для каждого Эл из Строка Цикл
			Value.Добавить(СтрЗаменить(Эл, """", ""));
		КонецЦикла;
		Values.Добавить(Value);
	КонецЦикла;
	Структура.Вставить("values", Values);
 	
	ЗаписатьJSON(JSON, Структура);
	
	Ответ = Новый Структура;
	Ответ.Вставить("JSON", JSON.Закрыть());
	Ответ.Вставить("RANGE", Range);
	Возврат Ответ;
КонецФункции

//Функция возвращает JSON в формате строки, необходимый для очищения таблицы.
//Важно. Таблица будет очищаться только по столбцам от A до AA (вкл.). Можете изменить это сами.
Функция JSON_ОчищениеТаблицы()
	JSON = Новый ЗаписьJSON;
	ПараметрыЗаписиJSON = Новый         
        ПараметрыЗаписиJSON(ПереносСтрокJSON.Нет,"",ложь,ЭкранированиеСимволовJSON.Нет,Ложь,Ложь,Ложь,Ложь,Ложь);
	JSON.УстановитьСтроку(ПараметрыЗаписиJSON);
	Структура = Новый Структура;
	Ranges = Новый Массив;
	Ranges.Добавить("A:AA");
	Структура.Вставить("ranges", Ranges);
	ЗаписатьJSON(JSON, Структура);
	Возврат JSON.Закрыть();
КонецФункции
#КонецОбласти