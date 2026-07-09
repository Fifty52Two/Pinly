import Foundation

// MARK: - Badge

enum Badge: String, CaseIterable {
    // Mekan sayısı
    case ilkAdim      = "ilkAdim"
    case besli        = "besli"
    case onlu         = "onlu"
    case yirmili      = "yirmili"
    case ellili       = "ellili"
    case yuzlu        = "yuzlu"
    // Ziyaret
    case ilkZiyaret   = "ilkZiyaret"
    case onZiyaret    = "onZiyaret"
    // Rota
    case gezgin       = "gezgin"
    case rotaci       = "rotaci"
    case rotaUstasi   = "rotaUstasi"
    case planlamaci   = "planlamaci"
    // Keşif
    case kasif        = "kasif"
    case parkSever    = "parkSever"
    case muzeSever    = "muzeSever"
    // Yemek
    case gurme        = "gurme"
    // Zaman
    case sabahciKus   = "sabahciKus"
    case geceKusu     = "geceKusu"
    // Sosyal
    case paylasimci   = "paylasimci"
    case sosyalKelebek = "sosyalKelebek"
    // Sadakat
    case hafizalik    = "hafizalik"

    var title: String {
        switch self {
        case .ilkAdim:       return NSLocalizedString("badge.ilkAdim.title", comment: "")
        case .besli:         return NSLocalizedString("badge.besli.title", comment: "")
        case .onlu:          return NSLocalizedString("badge.onlu.title", comment: "")
        case .yirmili:       return NSLocalizedString("badge.yirmili.title", comment: "")
        case .ellili:        return NSLocalizedString("badge.ellili.title", comment: "")
        case .yuzlu:         return NSLocalizedString("badge.yuzlu.title", comment: "")
        case .ilkZiyaret:    return NSLocalizedString("badge.ilkZiyaret.title", comment: "")
        case .onZiyaret:     return NSLocalizedString("badge.onZiyaret.title", comment: "")
        case .gezgin:        return NSLocalizedString("badge.gezgin.title", comment: "")
        case .rotaci:        return NSLocalizedString("badge.rotaci.title", comment: "")
        case .rotaUstasi:    return NSLocalizedString("badge.rotaUstasi.title", comment: "")
        case .planlamaci:    return NSLocalizedString("badge.planlamaci.title", comment: "")
        case .kasif:         return NSLocalizedString("badge.kasif.title", comment: "")
        case .parkSever:     return NSLocalizedString("badge.parkSever.title", comment: "")
        case .muzeSever:     return NSLocalizedString("badge.muzeSever.title", comment: "")
        case .gurme:         return NSLocalizedString("badge.gurme.title", comment: "")
        case .sabahciKus:    return NSLocalizedString("badge.sabahciKus.title", comment: "")
        case .geceKusu:      return NSLocalizedString("badge.geceKusu.title", comment: "")
        case .paylasimci:    return NSLocalizedString("badge.paylasimci.title", comment: "")
        case .sosyalKelebek: return NSLocalizedString("badge.sosyalKelebek.title", comment: "")
        case .hafizalik:     return NSLocalizedString("badge.hafizalik.title", comment: "")
        }
    }

    var description: String {
        switch self {
        case .ilkAdim:       return NSLocalizedString("badge.ilkAdim.desc", comment: "")
        case .besli:         return NSLocalizedString("badge.besli.desc", comment: "")
        case .onlu:          return NSLocalizedString("badge.onlu.desc", comment: "")
        case .yirmili:       return NSLocalizedString("badge.yirmili.desc", comment: "")
        case .ellili:        return NSLocalizedString("badge.ellili.desc", comment: "")
        case .yuzlu:         return NSLocalizedString("badge.yuzlu.desc", comment: "")
        case .ilkZiyaret:    return NSLocalizedString("badge.ilkZiyaret.desc", comment: "")
        case .onZiyaret:     return NSLocalizedString("badge.onZiyaret.desc", comment: "")
        case .gezgin:        return NSLocalizedString("badge.gezgin.desc", comment: "")
        case .rotaci:        return NSLocalizedString("badge.rotaci.desc", comment: "")
        case .rotaUstasi:    return NSLocalizedString("badge.rotaUstasi.desc", comment: "")
        case .planlamaci:    return NSLocalizedString("badge.planlamaci.desc", comment: "")
        case .kasif:         return NSLocalizedString("badge.kasif.desc", comment: "")
        case .parkSever:     return NSLocalizedString("badge.parkSever.desc", comment: "")
        case .muzeSever:     return NSLocalizedString("badge.muzeSever.desc", comment: "")
        case .gurme:         return NSLocalizedString("badge.gurme.desc", comment: "")
        case .sabahciKus:    return NSLocalizedString("badge.sabahciKus.desc", comment: "")
        case .geceKusu:      return NSLocalizedString("badge.geceKusu.desc", comment: "")
        case .paylasimci:    return NSLocalizedString("badge.paylasimci.desc", comment: "")
        case .sosyalKelebek: return NSLocalizedString("badge.sosyalKelebek.desc", comment: "")
        case .hafizalik:     return NSLocalizedString("badge.hafizalik.desc", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .ilkAdim:       return "mappin.circle.fill"
        case .besli:         return "star.circle.fill"
        case .onlu:          return "rosette"
        case .yirmili:       return "medal.fill"
        case .ellili:        return "trophy.fill"
        case .yuzlu:         return "crown.fill"
        case .ilkZiyaret:    return "checkmark.seal.fill"
        case .onZiyaret:     return "figure.walk.motion"
        case .gezgin:        return "figure.walk.circle.fill"
        case .rotaci:        return "map.fill"
        case .rotaUstasi:    return "map.circle.fill"
        case .planlamaci:    return "bookmark.fill"
        case .kasif:         return "binoculars.fill"
        case .parkSever:     return "leaf.fill"
        case .muzeSever:     return "building.columns.fill"
        case .gurme:         return "fork.knife.circle.fill"
        case .sabahciKus:    return "sunrise.fill"
        case .geceKusu:      return "moon.stars.fill"
        case .paylasimci:    return "square.and.arrow.up.circle.fill"
        case .sosyalKelebek: return "person.2.fill"
        case .hafizalik:     return "calendar.badge.checkmark"
        }
    }

    var color: String {
        switch self {
        case .ilkAdim:       return "blue"
        case .besli:         return "yellow"
        case .onlu:          return "orange"
        case .yirmili:       return "purple"
        case .ellili:        return "red"
        case .yuzlu:         return "red"
        case .ilkZiyaret:    return "green"
        case .onZiyaret:     return "green"
        case .gezgin:        return "teal"
        case .rotaci:        return "teal"
        case .rotaUstasi:    return "teal"
        case .planlamaci:    return "indigo"
        case .kasif:         return "indigo"
        case .parkSever:     return "green"
        case .muzeSever:     return "brown"
        case .gurme:         return "pink"
        case .sabahciKus:    return "orange"
        case .geceKusu:      return "purple"
        case .paylasimci:    return "cyan"
        case .sosyalKelebek: return "cyan"
        case .hafizalik:     return "blue"
        }
    }
}
