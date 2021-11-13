local mod = {
    id = "IntelligentAI",
    name = "Intelligent AI",
    version = "0.1.0.20211114",
    requirements = {"kf_ModUtils"},
    modApiVersion = "2.6.3",
    icon = "img/icon.png",
    author = "Compartany",
    description = "Do you find the game too easy because Vek's AI is too low? This MOD will completely change it."
}
print(mod.version) -- for package and release

function mod:init()
    intelAI_modApiExt = require(self.scriptPath .. "modApiExt/modApiExt")
    intelAI_modApiExt:init()
    self:loadText()
    self:initScripts()
    self:initOptions()
end

-- 改变设置、继续游戏都会重新加载
function mod:load(options, version)
    intelAI_modApiExt:load(self, options, version)
    self:loadScripts(options)
end

function mod:loadScripts(options)
    self.ai:Load(options)
end

function mod:initScripts()
    self.ai = require(self.scriptPath .. "ai")
end

function mod:initOptions()
    modApi:addGenerationOption("opt_factor", IntelAIMod_Texts.opt_factor_title, IntelAIMod_Texts.opt_factor_text, {values = {0.1, 0.2, 0.3, 0.4, 0.5}, value = 0.5})
    modApi:addGenerationOption("opt_vh_mode", IntelAIMod_Texts.opt_vh_mode_title, IntelAIMod_Texts.opt_vh_mode_text, {enabled = true})
    modApi:addGenerationOption("opt_im_mode", IntelAIMod_Texts.opt_im_mode_title, IntelAIMod_Texts.opt_im_mode_text, {enabled = true})
    modApi:addGenerationOption("opt_readme", IntelAIMod_Texts.opt_readme_title, IntelAIMod_Texts.opt_readme_text, {values = {"-"}})
    modApi:addGenerationOption("opt_debug", "DEBUG INFO", "DEBUG INFO", {values = {"NONE", "TARGET", "POSITION", "ALL"}, value = "NONE"})

end

function mod:loadText()
    local langPath = nil
    local language = modApi:getLanguageIndex()
    if language == Languages.Chinese_Simplified then
        langPath = self.scriptPath .. "localization/chinese/"
    else
        langPath = self.scriptPath .. "localization/english/"
    end
    IntelAIMod_Texts = require(langPath .. "Mod_Texts")
end

return mod
