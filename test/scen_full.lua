return {
  { t = 6, dump = "after wake", snap = true },
  { t = 7, type = "TEST\r" },
  { t = 52, dump = "after TEST", snap = true },
  { t = 53, type = "LONG\r" },
  { t = 57, dump = "after LONG" },
  { t = 58, key = "F1" },
  { t = 59, dump = "help", snap = true },
  { t = 60, key = "F2" },
  { t = 61, type = "Y" },
  { t = 62, check = true },
  { t = 63, exit = true },
}
