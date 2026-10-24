// libintl-lite: see libintl.h. Catalogs are read whole and kept in memory, one per (domain, language).
#include "libintl.h"

#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <initializer_list>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

// Plural-Forms "plural=EXPR": the C subset gettext allows (n, integers, ! * / % + - < > <= >= == != && || ?:)
class PluralExpr
{
public:
  explicit PluralExpr(std::string s) : src_(std::move(s)) {}
  unsigned long eval(unsigned long n)
  {
    n_ = n;
    pos_ = 0;
    ok_ = true;
    const unsigned long v = ternary();
    return ok_ ? v : (n != 1);
  }

private:
  std::string src_;
  size_t pos_ = 0;
  unsigned long n_ = 0;
  bool ok_ = true;

  void ws() { while (pos_ < src_.size() && isspace((unsigned char)src_[pos_])) ++pos_; }
  bool eat(const char *op)
  {
    ws();
    const size_t l = strlen(op);
    if (src_.compare(pos_, l, op) != 0) return false;
    // don't take "<" from "<=", "=" etc.
    if (l == 1 && pos_ + 1 < src_.size() && strchr("<>=!", op[0]) && src_[pos_ + 1] == '=') return false;
    if (l == 1 && (op[0] == '&' || op[0] == '|')) return false;
    pos_ += l;
    return true;
  }
  unsigned long ternary()
  {
    const unsigned long c = lor();
    if (eat("?")) {
      const unsigned long a = ternary();
      if (!eat(":")) ok_ = false;
      const unsigned long b = ternary();
      return c ? a : b;
    }
    return c;
  }
  unsigned long lor() { unsigned long v = land(); while (eat("||")) { const unsigned long r = land(); v = v || r; } return v; }
  unsigned long land() { unsigned long v = eq(); while (eat("&&")) { const unsigned long r = eq(); v = v && r; } return v; }
  unsigned long eq()
  {
    unsigned long v = rel();
    for (;;) {
      if (eat("==")) v = v == rel();
      else if (eat("!=")) v = v != rel();
      else return v;
    }
  }
  unsigned long rel()
  {
    unsigned long v = add();
    for (;;) {
      if (eat("<=")) v = v <= add();
      else if (eat(">=")) v = v >= add();
      else if (eat("<")) v = v < add();
      else if (eat(">")) v = v > add();
      else return v;
    }
  }
  unsigned long add()
  {
    unsigned long v = mul();
    for (;;) {
      if (eat("+")) v = v + mul();
      else if (eat("-")) v = v - mul();
      else return v;
    }
  }
  unsigned long mul()
  {
    unsigned long v = unary();
    for (;;) {
      if (eat("*")) v = v * unary();
      else if (eat("/")) { const unsigned long d = unary(); v = d ? v / d : (ok_ = false, 0); }
      else if (eat("%")) { const unsigned long d = unary(); v = d ? v % d : (ok_ = false, 0); }
      else return v;
    }
  }
  unsigned long unary()
  {
    if (eat("!")) return !unary();
    return primary();
  }
  unsigned long primary()
  {
    ws();
    if (eat("(")) {
      const unsigned long v = ternary();
      if (!eat(")")) ok_ = false;
      return v;
    }
    if (pos_ < src_.size() && src_[pos_] == 'n') { ++pos_; return n_; }
    if (pos_ < src_.size() && isdigit((unsigned char)src_[pos_])) {
      unsigned long v = 0;
      while (pos_ < src_.size() && isdigit((unsigned char)src_[pos_])) v = v * 10 + (src_[pos_++] - '0');
      return v;
    }
    ok_ = false;
    return 0;
  }
};

struct Catalog {
  std::unordered_map<std::string, std::string> msgs;  // msgid (plural: id NUL id_plural) -> msgstr (plurals NUL separated)
  std::unique_ptr<PluralExpr> plural;
};

bool loadMo(const std::string& path, Catalog& cat)
{
  std::ifstream in(path, std::ios::binary);
  if (!in) return false;
  const std::string d((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
  if (d.size() < 28) return false;
  auto u32 = [&](size_t off, bool swap) -> uint32_t {
    uint32_t v;
    memcpy(&v, d.data() + off, 4);
    return swap ? __builtin_bswap32(v) : v;
  };
  const uint32_t magic = u32(0, false);
  const bool swap = magic == 0xde120495u;
  if (!swap && magic != 0x950412deu) return false;
  const uint32_t count = u32(8, swap), ko = u32(12, swap), vo = u32(16, swap);
  if (uint64_t(ko) + 8ull * count > d.size() || uint64_t(vo) + 8ull * count > d.size()) return false;
  for (uint32_t i = 0; i < count; ++i) {
    const uint32_t kl = u32(ko + 8 * i, swap), kp = u32(ko + 8 * i + 4, swap);
    const uint32_t vl = u32(vo + 8 * i, swap), vp = u32(vo + 8 * i + 4, swap);
    if (uint64_t(kp) + kl > d.size() || uint64_t(vp) + vl > d.size()) return false;
    cat.msgs.emplace(d.substr(kp, kl), d.substr(vp, vl));
  }
  // header: Plural-Forms: nplurals=N; plural=EXPR;
  const auto h = cat.msgs.find("");
  if (h != cat.msgs.end()) {
    const size_t p = h->second.find("plural=", h->second.find("Plural-Forms:"));
    if (h->second.find("Plural-Forms:") != std::string::npos && p != std::string::npos) {
      size_t e = h->second.find_first_of(";\n", p);
      cat.plural = std::make_unique<PluralExpr>(h->second.substr(p + 7, e == std::string::npos ? e : e - p - 7));
    }
  }
  return true;
}

// Constructed on first use: gettext() is called from other libraries' static initializers, possibly before ours ran.
struct State {
  std::mutex mtx;
  std::string currentDomain = "messages";
  std::map<std::string, std::string> boundDirs;
  std::map<std::string, std::unique_ptr<Catalog>> catalogs;  // "domain\x01lang" -> catalog (null: none found)
  std::vector<std::unique_ptr<char[]>> returned;            // strings handed out for domain/dir queries
};
State& state()
{
  static State *s = new State;  // never destroyed: gettext() may also run from static destructors
  return *s;
}

std::string language()
{
  for (const char *v : {"LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"}) {
    const char *s = getenv(v);
    if (s && *s) return s;
  }
  return "C";
}

// candidates for "de_DE.UTF-8@euro:fr" -> de_DE, de, fr
std::vector<std::string> languageCandidates(const std::string& spec)
{
  std::vector<std::string> out;
  size_t start = 0;
  while (start <= spec.size()) {
    size_t end = spec.find(':', start);
    if (end == std::string::npos) end = spec.size();
    std::string l = spec.substr(start, end - start);
    l = l.substr(0, l.find_first_of(".@"));
    if (!l.empty() && l != "C" && l != "POSIX") {
      out.push_back(l);
      const size_t us = l.find('_');
      if (us != std::string::npos) out.push_back(l.substr(0, us));
    }
    start = end + 1;
  }
  return out;
}

const Catalog *catalogFor(const std::string& domain)
{
  const std::string lang = language();
  const std::string key = domain + '\x01' + lang;
  auto it = state().catalogs.find(key);
  if (it != state().catalogs.end()) return it->second.get();
  std::unique_ptr<Catalog> cat;
  const auto dir = state().boundDirs.find(domain);
  if (dir != state().boundDirs.end()) {
    for (const auto& l : languageCandidates(lang)) {
      auto c = std::make_unique<Catalog>();
      if (loadMo(dir->second + "/" + l + "/LC_MESSAGES/" + domain + ".mo", *c)) {
        cat = std::move(c);
        break;
      }
    }
  }
  return (state().catalogs[key] = std::move(cat)).get();
}

char *keep(const std::string& s)
{
  auto p = std::make_unique<char[]>(s.size() + 1);
  memcpy(p.get(), s.c_str(), s.size() + 1);
  state().returned.push_back(std::move(p));
  return state().returned.back().get();
}

}  // namespace

extern "C" {

char *dcngettext(const char *domain, const char *msgid, const char *msgid_plural, unsigned long n, int)
{
  if (!msgid) return nullptr;
  std::lock_guard<std::mutex> lock(state().mtx);
  const Catalog *cat = catalogFor(domain ? domain : state().currentDomain);
  const char *fallback = (msgid_plural && n != 1) ? msgid_plural : msgid;
  if (!cat) return const_cast<char *>(fallback);
  std::string key = msgid;
  if (msgid_plural) {
    key.push_back('\0');
    key += msgid_plural;
  }
  const auto it = cat->msgs.find(key);
  if (it == cat->msgs.end()) return const_cast<char *>(fallback);
  if (!msgid_plural) return const_cast<char *>(it->second.c_str());
  unsigned long idx = cat->plural ? cat->plural->eval(n) : (n != 1);
  const char *s = it->second.c_str();
  const char *end = s + it->second.size();
  while (idx-- > 0) {
    s += strlen(s) + 1;
    if (s >= end) return const_cast<char *>(fallback);
  }
  return const_cast<char *>(s);
}

char *dcgettext(const char *domain, const char *msgid, int category) { return dcngettext(domain, msgid, nullptr, 1, category); }
char *dgettext(const char *domain, const char *msgid) { return dcngettext(domain, msgid, nullptr, 1, LC_MESSAGES); }
char *gettext(const char *msgid) { return dcngettext(nullptr, msgid, nullptr, 1, LC_MESSAGES); }
char *ngettext(const char *msgid, const char *msgid_plural, unsigned long n)
{
  return dcngettext(nullptr, msgid, msgid_plural, n, LC_MESSAGES);
}
char *dngettext(const char *domain, const char *msgid, const char *msgid_plural, unsigned long n)
{
  return dcngettext(domain, msgid, msgid_plural, n, LC_MESSAGES);
}

char *textdomain(const char *domainname)
{
  std::lock_guard<std::mutex> lock(state().mtx);
  if (domainname && *domainname) state().currentDomain = domainname;
  return keep(state().currentDomain);
}

char *bindtextdomain(const char *domainname, const char *dirname)
{
  if (!domainname || !*domainname) return nullptr;
  std::lock_guard<std::mutex> lock(state().mtx);
  if (dirname) {
    state().boundDirs[domainname] = dirname;
    for (auto it = state().catalogs.begin(); it != state().catalogs.end();)  // reload from the new folder
      it = it->first.rfind(std::string(domainname) + '\x01', 0) == 0 ? state().catalogs.erase(it) : std::next(it);
  }
  const auto it = state().boundDirs.find(domainname);
  return it == state().boundDirs.end() ? nullptr : keep(it->second);
}

char *bind_textdomain_codeset(const char *, const char *codeset) { return const_cast<char *>(codeset ? codeset : "UTF-8"); }

}  // extern "C"
