return function(chinese)
    local menu = {OptionType={BOOLEAN=4, NUMBER=5}, IsVisible=false,
        i18n=chinese and "Chinese" or nil, options={}, registrations=0, removals=0}
    function menu.AddSetting(category, subcategory, setting)
        assert(category == "I can touch forever!" and subcategory == nil)
        menu.options[#menu.options+1] = setting
        menu.registrations = menu.registrations+1
    end
    function menu.RemoveCategory(category)
        if category == "Mouse Pickup" then menu.removals = menu.removals+1; return end
        assert(category == "I can touch forever!")
        menu.options = {}
        menu.removals = menu.removals+1
    end
    if chinese then
        function menu.SetCategoryNameTranslate(category, name)
            assert(category == "I can touch forever!")
            menu.name = name
        end
    end
    return menu
end
